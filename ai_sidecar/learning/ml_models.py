"""
ML Model Wrappers for Learning Engine.

Provides a consistent interface for different ML algorithms
including Random Forest, Gradient Boosting, and ensemble methods.
"""

from abc import ABC, abstractmethod
from enum import Enum
from typing import Any, Dict, List, Optional, Tuple

import numpy as np
from pydantic import BaseModel, Field
from sklearn.ensemble import (
    GradientBoostingClassifier,
    HistGradientBoostingClassifier,
    RandomForestClassifier,
)
from sklearn.metrics import (
    accuracy_score,
    f1_score,
    precision_score,
    recall_score,
)
from sklearn.model_selection import train_test_split

from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)


class ModelType(str, Enum):
    """Supported model types."""
    
    RANDOM_FOREST = "random_forest"
    GRADIENT_BOOSTING = "gradient_boosting"
    HIST_GRADIENT_BOOSTING = "hist_gradient_boosting"


class TrainingConfig(BaseModel):
    """Configuration for model training."""
    
    model_type: ModelType = ModelType.RANDOM_FOREST
    
    # Train/test split
    test_size: float = 0.2
    validation_size: float = 0.1
    random_state: int = 42
    
    # Random Forest hyperparameters
    rf_n_estimators: int = 100
    rf_max_depth: Optional[int] = 10
    rf_min_samples_split: int = 5
    rf_min_samples_leaf: int = 2
    rf_max_features: str = "sqrt"
    
    # Gradient Boosting hyperparameters
    gb_n_estimators: int = 100
    gb_learning_rate: float = 0.1
    gb_max_depth: int = 5
    gb_min_samples_split: int = 5
    gb_min_samples_leaf: int = 2
    
    # Hist Gradient Boosting hyperparameters
    hgb_max_iter: int = 100
    hgb_learning_rate: float = 0.1
    hgb_max_depth: Optional[int] = 10
    hgb_min_samples_leaf: int = 20
    hgb_l2_regularization: float = 0.0
    
    # Class balancing
    class_weight: Optional[str] = "balanced"


class TrainingResult(BaseModel):
    """Results from model training."""
    
    model_type: str
    training_samples: int
    validation_samples: int
    test_samples: int
    
    # Metrics on test set
    accuracy: float = 0.0
    precision: float = 0.0
    recall: float = 0.0
    f1_score: float = 0.0
    
    # Feature importance
    feature_importances: Dict[str, float] = Field(default_factory=dict)
    
    # Training info
    training_time_seconds: float = 0.0
    hyperparameters: Dict[str, Any] = Field(default_factory=dict)
    
    # Class distribution
    class_distribution: Dict[str, int] = Field(default_factory=dict)


class PredictionResult(BaseModel):
    """Results from model prediction."""
    
    predicted_class: Any
    confidence: float
    class_probabilities: Dict[str, float] = Field(default_factory=dict)
    feature_contributions: Dict[str, float] = Field(default_factory=dict)


class BaseMLModel(ABC):
    """
    Abstract base class for ML models.
    
    Provides consistent interface for training and prediction.
    """
    
    def __init__(self, config: Optional[TrainingConfig] = None):
        """
        Initialize model wrapper.
        
        Args:
            config: Training configuration
        """
        self.config = config or TrainingConfig()
        self._model: Any = None
        self._is_trained = False
        self._feature_names: List[str] = []
        self._classes: List[Any] = []
    
    @abstractmethod
    def _create_model(self) -> Any:
        """Create the underlying sklearn model."""
        pass
    
    @abstractmethod
    def get_model_type(self) -> str:
        """Get model type identifier."""
        pass
    
    def train(
        self,
        X: np.ndarray,
        y: np.ndarray,
        feature_names: Optional[List[str]] = None
    ) -> TrainingResult:
        """
        Train the model.
        
        Args:
            X: Feature matrix
            y: Labels
            feature_names: Names of features for interpretation
            
        Returns:
            TrainingResult with metrics
        """
        import time
        start_time = time.time()
        
        if len(X) == 0:
            logger.error("train_called_with_empty_data")
            raise ValueError("Cannot train with empty data")
        
        logger.info(
            "training_model",
            model_type=self.get_model_type(),
            n_samples=len(X),
            n_features=X.shape[1] if len(X.shape) > 1 else 1
        )
        
        self._feature_names = feature_names or [
            f"feature_{i}" for i in range(X.shape[1])
        ]
        
        # Split data
        X_train_val, X_test, y_train_val, y_test = train_test_split(
            X, y,
            test_size=self.config.test_size,
            random_state=self.config.random_state,
            stratify=y if len(np.unique(y)) > 1 else None
        )
        
        X_train, X_val, y_train, y_val = train_test_split(
            X_train_val, y_train_val,
            test_size=self.config.validation_size,
            random_state=self.config.random_state,
            stratify=y_train_val if len(np.unique(y_train_val)) > 1 else None
        )
        
        logger.debug(
            "data_split",
            train=len(X_train),
            val=len(X_val),
            test=len(X_test)
        )
        
        # Create and train model
        self._model = self._create_model()
        self._model.fit(X_train, y_train)
        self._classes = list(self._model.classes_)
        self._is_trained = True
        
        # Evaluate on test set
        y_pred = self._model.predict(X_test)
        
        # Calculate metrics
        accuracy = accuracy_score(y_test, y_pred)
        precision = precision_score(y_test, y_pred, average="weighted", zero_division=0)
        recall = recall_score(y_test, y_pred, average="weighted", zero_division=0)
        f1 = f1_score(y_test, y_pred, average="weighted", zero_division=0)
        
        # Get feature importances
        feature_importances = {}
        if hasattr(self._model, "feature_importances_"):
            for name, importance in zip(self._feature_names, self._model.feature_importances_):
                feature_importances[name] = float(importance)
        
        # Class distribution
        unique, counts = np.unique(y, return_counts=True)
        class_distribution = {str(c): int(n) for c, n in zip(unique, counts)}
        
        training_time = time.time() - start_time
        
        result = TrainingResult(
            model_type=self.get_model_type(),
            training_samples=len(X_train),
            validation_samples=len(X_val),
            test_samples=len(X_test),
            accuracy=accuracy,
            precision=precision,
            recall=recall,
            f1_score=f1,
            feature_importances=feature_importances,
            training_time_seconds=training_time,
            hyperparameters=self._get_hyperparameters(),
            class_distribution=class_distribution
        )
        
        logger.info(
            "training_complete",
            model_type=self.get_model_type(),
            accuracy=f"{accuracy:.4f}",
            f1=f"{f1:.4f}",
            training_time=f"{training_time:.2f}s"
        )
        
        return result
    
    def predict(self, X: np.ndarray) -> List[PredictionResult]:
        """
        Make predictions.
        
        Args:
            X: Feature matrix
            
        Returns:
            List of PredictionResult objects
        """
        if not self._is_trained:
            raise RuntimeError("Model must be trained before prediction")
        
        if len(X.shape) == 1:
            X = X.reshape(1, -1)
        
        predictions = []
        
        # Get class predictions and probabilities
        y_pred = self._model.predict(X)
        y_proba = self._model.predict_proba(X)
        
        for i, (pred, proba) in enumerate(zip(y_pred, y_proba)):
            # Build class probabilities dict
            class_probs = {
                str(cls): float(p) for cls, p in zip(self._classes, proba)
            }
            
            # Get confidence (probability of predicted class)
            confidence = float(max(proba))
            
            predictions.append(PredictionResult(
                predicted_class=pred,
                confidence=confidence,
                class_probabilities=class_probs,
                feature_contributions={}
            ))
        
        logger.debug(
            "predictions_made",
            n_samples=len(X),
            model_type=self.get_model_type()
        )
        
        return predictions
    
    def predict_single(self, x: np.ndarray) -> PredictionResult:
        """
        Make single prediction.
        
        Args:
            x: Single feature vector
            
        Returns:
            PredictionResult
        """
        results = self.predict(x.reshape(1, -1))
        return results[0]
    
    @abstractmethod
    def _get_hyperparameters(self) -> Dict[str, Any]:
        """Get hyperparameters used for training."""
        pass
    
    def get_model(self) -> Any:
        """Get underlying sklearn model."""
        return self._model
    
    def set_model(self, model: Any) -> None:
        """Set underlying sklearn model (for loading)."""
        self._model = model
        self._is_trained = True
        if hasattr(model, "classes_"):
            self._classes = list(model.classes_)
    
    def is_trained(self) -> bool:
        """Check if model is trained."""
        return self._is_trained
    
    def get_feature_importance(self) -> Dict[str, float]:
        """Get feature importances."""
        if not self._is_trained or not hasattr(self._model, "feature_importances_"):
            return {}
        
        return {
            name: float(imp)
            for name, imp in zip(self._feature_names, self._model.feature_importances_)
        }


class RandomForestModel(BaseMLModel):
    """Random Forest Classifier wrapper."""
    
    def _create_model(self) -> RandomForestClassifier:
        """Create Random Forest model."""
        return RandomForestClassifier(
            n_estimators=self.config.rf_n_estimators,
            max_depth=self.config.rf_max_depth,
            min_samples_split=self.config.rf_min_samples_split,
            min_samples_leaf=self.config.rf_min_samples_leaf,
            max_features=self.config.rf_max_features,
            class_weight=self.config.class_weight,
            random_state=self.config.random_state,
            n_jobs=-1
        )
    
    def get_model_type(self) -> str:
        return ModelType.RANDOM_FOREST.value
    
    def _get_hyperparameters(self) -> Dict[str, Any]:
        return {
            "n_estimators": self.config.rf_n_estimators,
            "max_depth": self.config.rf_max_depth,
            "min_samples_split": self.config.rf_min_samples_split,
            "min_samples_leaf": self.config.rf_min_samples_leaf,
            "max_features": self.config.rf_max_features,
            "class_weight": self.config.class_weight
        }


class GradientBoostingModel(BaseMLModel):
    """Gradient Boosting Classifier wrapper."""
    
    def _create_model(self) -> GradientBoostingClassifier:
        """Create Gradient Boosting model."""
        return GradientBoostingClassifier(
            n_estimators=self.config.gb_n_estimators,
            learning_rate=self.config.gb_learning_rate,
            max_depth=self.config.gb_max_depth,
            min_samples_split=self.config.gb_min_samples_split,
            min_samples_leaf=self.config.gb_min_samples_leaf,
            random_state=self.config.random_state
        )
    
    def get_model_type(self) -> str:
        return ModelType.GRADIENT_BOOSTING.value
    
    def _get_hyperparameters(self) -> Dict[str, Any]:
        return {
            "n_estimators": self.config.gb_n_estimators,
            "learning_rate": self.config.gb_learning_rate,
            "max_depth": self.config.gb_max_depth,
            "min_samples_split": self.config.gb_min_samples_split,
            "min_samples_leaf": self.config.gb_min_samples_leaf
        }


class HistGradientBoostingModel(BaseMLModel):
    """
    Histogram-based Gradient Boosting wrapper.
    
    Faster for large datasets with native support for missing values.
    """
    
    def _create_model(self) -> HistGradientBoostingClassifier:
        """Create Hist Gradient Boosting model."""
        return HistGradientBoostingClassifier(
            max_iter=self.config.hgb_max_iter,
            learning_rate=self.config.hgb_learning_rate,
            max_depth=self.config.hgb_max_depth,
            min_samples_leaf=self.config.hgb_min_samples_leaf,
            l2_regularization=self.config.hgb_l2_regularization,
            random_state=self.config.random_state
        )
    
    def get_model_type(self) -> str:
        return ModelType.HIST_GRADIENT_BOOSTING.value
    
    def _get_hyperparameters(self) -> Dict[str, Any]:
        return {
            "max_iter": self.config.hgb_max_iter,
            "learning_rate": self.config.hgb_learning_rate,
            "max_depth": self.config.hgb_max_depth,
            "min_samples_leaf": self.config.hgb_min_samples_leaf,
            "l2_regularization": self.config.hgb_l2_regularization
        }


def create_model(
    model_type: ModelType | str,
    config: Optional[TrainingConfig] = None
) -> BaseMLModel:
    """
    Factory function to create ML model.
    
    Args:
        model_type: Type of model to create
        config: Training configuration
        
    Returns:
        Configured ML model wrapper
    """
    if isinstance(model_type, str):
        model_type = ModelType(model_type)
    
    config = config or TrainingConfig(model_type=model_type)
    
    model_map = {
        ModelType.RANDOM_FOREST: RandomForestModel,
        ModelType.GRADIENT_BOOSTING: GradientBoostingModel,
        ModelType.HIST_GRADIENT_BOOSTING: HistGradientBoostingModel
    }
    
    model_class = model_map.get(model_type)
    if not model_class:
        raise ValueError(f"Unknown model type: {model_type}")
    
    return model_class(config)