"""
Self-Learning Engine using experience replay and strategy adaptation.

Learns from decisions, outcomes, and patterns to improve over time.
Integrates ML models for decision prediction and optimization.
"""

import json
import threading
from datetime import datetime, timedelta
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

import numpy as np

from ai_sidecar.learning.feature_extraction import FeatureConfig, FeatureExtractor
from ai_sidecar.learning.ml_models import (
    BaseMLModel,
    ModelType,
    PredictionResult,
    TrainingConfig,
    TrainingResult,
    create_model,
)
from ai_sidecar.learning.model_persistence import ModelMetadata, ModelPersistence
from ai_sidecar.memory.decision_models import DecisionContext, DecisionOutcome, DecisionRecord
from ai_sidecar.memory.manager import MemoryManager
from ai_sidecar.memory.models import Memory, MemoryImportance, MemoryQuery, MemoryType
from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)


class LearningEngine:
    """
    Self-learning engine using experience replay and ML models.
    
    Features:
    - Decision outcome tracking
    - Experience replay learning
    - Strategy performance monitoring
    - Pattern discovery
    - ML model training and prediction
    - Model persistence and versioning
    """
    
    def __init__(
        self,
        memory_manager: MemoryManager | None = None,
        models_dir: str = "data/learning/models",
        training_config: Optional[TrainingConfig] = None,
        feature_config: Optional[FeatureConfig] = None
    ):
        """
        Initialize learning engine.
        
        Args:
            memory_manager: Memory manager instance. If None, creates a default one.
            models_dir: Directory for storing trained models
            training_config: Configuration for ML training
            feature_config: Configuration for feature extraction
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
        
        # ML components
        self._models_dir = Path(models_dir)
        self._training_config = training_config or TrainingConfig()
        self._feature_config = feature_config or FeatureConfig()
        
        # Model persistence layer
        self._persistence = ModelPersistence(models_dir)
        
        # Feature extractor (fitted during training)
        self._feature_extractor: Optional[FeatureExtractor] = None
        self._feature_extractor_path = self._models_dir / "feature_extractor.json"
        
        # Loaded models cache (model_name -> (model, metadata))
        self._model_cache: Dict[str, Tuple[BaseMLModel, ModelMetadata]] = {}
        self._cache_lock = threading.Lock()
        
        # Load feature extractor if exists
        self._load_feature_extractor()
        
        logger.info(
            "learning_engine_initialized",
            models_dir=str(self._models_dir),
            model_type=self._training_config.model_type.value
        )
    
    def _load_feature_extractor(self) -> None:
        """Load feature extractor state if exists."""
        try:
            if self._feature_extractor_path.exists():
                with open(self._feature_extractor_path, "r") as f:
                    data = json.load(f)
                self._feature_extractor = FeatureExtractor.from_dict(data)
                logger.debug("feature_extractor_loaded")
        except Exception as e:
            logger.warning("feature_extractor_load_failed", error=str(e))
            self._feature_extractor = None
    
    def _save_feature_extractor(self) -> None:
        """Save feature extractor state."""
        if self._feature_extractor:
            try:
                self._feature_extractor_path.parent.mkdir(parents=True, exist_ok=True)
                with open(self._feature_extractor_path, "w") as f:
                    json.dump(self._feature_extractor.to_dict(), f, indent=2)
                logger.debug("feature_extractor_saved")
            except Exception as e:
                logger.error("feature_extractor_save_failed", error=str(e))
    
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
    
    async def train(
        self,
        data: List[DecisionRecord] | None = None,
        model_name: str = "decision_model",
        model_type: Optional[ModelType | str] = None,
        use_decision_history: bool = True,
        min_samples: int = 50,
        label_type: str = "success"
    ) -> Dict[str, Any]:
        """
        Train an ML model on decision history.
        
        Args:
            data: Training data (DecisionRecord list). If None, uses decision history.
            model_name: Name identifier for the trained model
            model_type: Type of model to train (random_forest, gradient_boosting, etc.)
            use_decision_history: If True and data is None, fetch from memory
            min_samples: Minimum samples required for training
            label_type: Type of label to extract (success, reward, action)
            
        Returns:
            Training results dictionary with metrics and model info
        """
        logger.info(
            "train_called",
            model_name=model_name,
            model_type=str(model_type or self._training_config.model_type.value),
            data_provided=data is not None,
            use_decision_history=use_decision_history
        )
        
        try:
            # Gather training data
            records: List[DecisionRecord] = []
            
            if data is not None:
                records = data
            elif use_decision_history:
                # Fetch decision records from memory
                records = await self._fetch_decision_records()
            
            if not records:
                logger.warning("train_no_data_available")
                return {
                    "status": "failed",
                    "error": "No training data available",
                    "model_name": model_name,
                    "samples": 0
                }
            
            # Filter records with outcomes
            records_with_outcomes = [
                r for r in records
                if r.outcome is not None
            ]
            
            logger.info(
                "training_data_gathered",
                total_records=len(records),
                records_with_outcomes=len(records_with_outcomes)
            )
            
            if len(records_with_outcomes) < min_samples:
                logger.warning(
                    "insufficient_training_data",
                    available=len(records_with_outcomes),
                    required=min_samples
                )
                return {
                    "status": "failed",
                    "error": f"Insufficient training data: {len(records_with_outcomes)} < {min_samples}",
                    "model_name": model_name,
                    "samples": len(records_with_outcomes)
                }
            
            # Initialize or update feature extractor
            if self._feature_extractor is None:
                self._feature_extractor = FeatureExtractor(self._feature_config)
            
            # Extract features
            logger.debug("extracting_features")
            X, feature_names = self._feature_extractor.fit_transform(records_with_outcomes)
            y, label_names = self._feature_extractor.extract_labels(
                records_with_outcomes,
                label_type=label_type
            )
            
            logger.debug(
                "features_extracted",
                n_samples=len(X),
                n_features=len(feature_names),
                unique_labels=len(set(y))
            )
            
            # Validate data
            if len(X) == 0 or len(np.unique(y)) < 2:
                logger.warning(
                    "training_data_insufficient_variance",
                    unique_labels=len(np.unique(y))
                )
                return {
                    "status": "failed",
                    "error": "Training data has insufficient variance (need at least 2 classes)",
                    "model_name": model_name,
                    "samples": len(X)
                }
            
            # Create and configure model
            effective_model_type = model_type or self._training_config.model_type
            if isinstance(effective_model_type, str):
                effective_model_type = ModelType(effective_model_type)
            
            config = TrainingConfig(
                model_type=effective_model_type,
                **{k: v for k, v in self._training_config.model_dump().items() if k != "model_type"}
            )
            
            ml_model = create_model(effective_model_type, config)
            
            # Train the model
            logger.info(
                "training_model",
                model_type=effective_model_type.value,
                n_samples=len(X),
                n_features=len(feature_names)
            )
            
            training_result: TrainingResult = ml_model.train(X, y, feature_names)
            
            # Prepare metadata for persistence
            metadata = {
                "training_samples": training_result.training_samples,
                "feature_names": feature_names,
                "feature_count": len(feature_names),
                "target_classes": [str(c) for c in label_names] if label_names else [],
                "accuracy": training_result.accuracy,
                "precision": training_result.precision,
                "recall": training_result.recall,
                "f1_score": training_result.f1_score,
                "hyperparameters": training_result.hyperparameters
            }
            
            # Save model
            logger.debug("saving_model", model_name=model_name)
            model_metadata = self._persistence.save_model(
                model=ml_model.get_model(),
                model_name=model_name,
                model_type=effective_model_type.value,
                metadata=metadata
            )
            
            # Save feature extractor state
            self._save_feature_extractor()
            
            # Update cache
            with self._cache_lock:
                self._model_cache[model_name] = (ml_model, model_metadata)
            
            # Build result
            result = {
                "status": "success",
                "model_name": model_name,
                "model_id": model_metadata.model_id,
                "model_type": effective_model_type.value,
                "version": model_metadata.version,
                "samples": training_result.training_samples,
                "accuracy": training_result.accuracy,
                "precision": training_result.precision,
                "recall": training_result.recall,
                "f1_score": training_result.f1_score,
                "training_time": training_result.training_time_seconds,
                "feature_importance": training_result.feature_importances,
                "class_distribution": training_result.class_distribution
            }
            
            logger.info(
                "training_complete",
                model_name=model_name,
                version=model_metadata.version,
                accuracy=f"{training_result.accuracy:.4f}",
                f1_score=f"{training_result.f1_score:.4f}"
            )
            
            return result
            
        except Exception as e:
            logger.error(
                "training_failed",
                model_name=model_name,
                error=str(e),
                exc_info=True
            )
            return {
                "status": "failed",
                "error": str(e),
                "model_name": model_name,
                "samples": len(data) if data else 0
            }
    
    async def predict(
        self,
        input_data: Dict[str, Any] | DecisionRecord,
        model_name: str = "decision_model",
        version: Optional[int] = None
    ) -> Optional[Dict[str, Any]]:
        """
        Make a prediction using a trained model.
        
        Args:
            input_data: Input data for prediction (dict or DecisionRecord)
            model_name: Name of model to use
            version: Specific model version (None for latest)
            
        Returns:
            Prediction result with class, confidence, and probabilities
        """
        logger.info(
            "predict_called",
            model_name=model_name,
            version=version,
            input_type=type(input_data).__name__
        )
        
        try:
            # Load model if not cached
            ml_model, model_metadata = await self._get_or_load_model(model_name, version)
            
            if ml_model is None:
                logger.warning(
                    "prediction_model_not_found",
                    model_name=model_name,
                    version=version
                )
                return None
            
            # Ensure feature extractor is loaded
            if self._feature_extractor is None:
                self._load_feature_extractor()
                if self._feature_extractor is None:
                    logger.error("prediction_no_feature_extractor")
                    return None
            
            # Convert input to DecisionRecord if needed
            if isinstance(input_data, dict):
                # Build a minimal DecisionRecord from dict
                context = DecisionContext(
                    game_state_snapshot=input_data.get("game_state", {}),
                    available_options=input_data.get("available_options", []),
                    considered_factors=input_data.get("considered_factors", []),
                    confidence_level=input_data.get("confidence_level", 0.5),
                    reasoning=input_data.get("reasoning", "")
                )
                record = DecisionRecord(
                    decision_type=input_data.get("decision_type", "unknown"),
                    action_taken=input_data.get("action_taken", {}),
                    context=context
                )
            else:
                record = input_data
            
            # Extract features
            X, _ = self._feature_extractor.transform([record])
            
            if len(X) == 0:
                logger.warning("prediction_empty_features")
                return None
            
            # Make prediction
            predictions: List[PredictionResult] = ml_model.predict(X)
            
            if not predictions:
                logger.warning("prediction_empty_result")
                return None
            
            pred = predictions[0]
            
            result = {
                "predicted_class": pred.predicted_class,
                "confidence": pred.confidence,
                "class_probabilities": pred.class_probabilities,
                "model_name": model_name,
                "model_version": model_metadata.version,
                "model_type": model_metadata.model_type,
                "model_accuracy": model_metadata.accuracy
            }
            
            logger.debug(
                "prediction_made",
                model_name=model_name,
                predicted_class=pred.predicted_class,
                confidence=f"{pred.confidence:.4f}"
            )
            
            return result
            
        except Exception as e:
            logger.error(
                "prediction_failed",
                model_name=model_name,
                error=str(e),
                exc_info=True
            )
            return None
    
    async def _get_or_load_model(
        self,
        model_name: str,
        version: Optional[int] = None
    ) -> Tuple[Optional[BaseMLModel], Optional[ModelMetadata]]:
        """
        Get model from cache or load from disk.
        
        Args:
            model_name: Name of model
            version: Specific version (None for latest)
            
        Returns:
            Tuple of (model, metadata) or (None, None) if not found
        """
        cache_key = f"{model_name}:v{version}" if version else model_name
        
        # Check cache
        with self._cache_lock:
            if cache_key in self._model_cache:
                logger.debug("model_cache_hit", model_name=model_name)
                return self._model_cache[cache_key]
        
        # Load from disk
        try:
            if not self._persistence.model_exists(model_name, version):
                return None, None
            
            sklearn_model, metadata = self._persistence.load_model(
                model_name, version
            )
            
            # Wrap in our model class
            ml_model = create_model(
                ModelType(metadata.model_type),
                self._training_config
            )
            ml_model.set_model(sklearn_model)
            
            # Cache it
            with self._cache_lock:
                self._model_cache[cache_key] = (ml_model, metadata)
            
            return ml_model, metadata
            
        except Exception as e:
            logger.error(
                "model_load_failed",
                model_name=model_name,
                version=version,
                error=str(e)
            )
            return None, None
    
    async def _fetch_decision_records(
        self,
        limit: int = 1000,
        time_range_hours: int = 168  # 1 week
    ) -> List[DecisionRecord]:
        """
        Fetch decision records from memory for training.
        
        Args:
            limit: Maximum records to fetch
            time_range_hours: Time range in hours
            
        Returns:
            List of DecisionRecord objects
        """
        logger.debug(
            "fetching_decision_records",
            limit=limit,
            time_range_hours=time_range_hours
        )
        
        query = MemoryQuery(
            memory_types=[MemoryType.DECISION],
            min_strength=0.1,
            time_range_hours=time_range_hours,
            limit=limit
        )
        
        memories = await self.memory.query(query)
        
        records = []
        for mem in memories:
            try:
                if isinstance(mem.content, dict):
                    record = DecisionRecord(**mem.content)
                    records.append(record)
            except Exception as e:
                logger.debug(
                    "record_parse_error",
                    memory_id=mem.memory_id,
                    error=str(e)
                )
                continue
        
        logger.info(
            "decision_records_fetched",
            total_memories=len(memories),
            valid_records=len(records)
        )
        
        return records
    
    async def incremental_train(
        self,
        new_records: List[DecisionRecord],
        model_name: str = "decision_model"
    ) -> Dict[str, Any]:
        """
        Perform incremental training with new decision records.
        
        Combines new records with historical data for improved learning.
        
        Args:
            new_records: New decision records to learn from
            model_name: Name of model to update
            
        Returns:
            Training results
        """
        logger.info(
            "incremental_train_called",
            new_records=len(new_records),
            model_name=model_name
        )
        
        # Fetch existing records
        historical_records = await self._fetch_decision_records(limit=500)
        
        # Combine with new records
        all_records = historical_records + new_records
        
        # Retrain with combined data
        return await self.train(
            data=all_records,
            model_name=model_name,
            use_decision_history=False
        )
    
    def list_models(self) -> List[Dict[str, Any]]:
        """List all available trained models."""
        return self._persistence.list_models()
    
    def get_model_info(
        self,
        model_name: str,
        version: Optional[int] = None
    ) -> Optional[Dict[str, Any]]:
        """
        Get information about a trained model.
        
        Args:
            model_name: Name of model
            version: Specific version (None for latest)
            
        Returns:
            Model information dict or None
        """
        try:
            if not self._persistence.model_exists(model_name, version):
                return None
            
            _, metadata = self._persistence.load_model(model_name, version)
            return metadata.model_dump()
        except Exception as e:
            logger.error(
                "get_model_info_failed",
                model_name=model_name,
                error=str(e)
            )
            return None
    
    def clear_model_cache(self) -> None:
        """Clear the in-memory model cache."""
        with self._cache_lock:
            self._model_cache.clear()
        self._persistence.clear_cache()
        logger.info("model_cache_cleared")
    
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