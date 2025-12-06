"""
Self-learning system for AI Sidecar.

Implements experience replay, strategy adaptation, and decision learning.
Provides ML model training and inference capabilities.
"""

from .engine import LearningEngine
from .feature_extraction import FeatureConfig, FeatureExtractor
from .ml_models import (
    BaseMLModel,
    GradientBoostingModel,
    HistGradientBoostingModel,
    ModelType,
    PredictionResult,
    RandomForestModel,
    TrainingConfig,
    TrainingResult,
    create_model,
)
from .model_persistence import ModelMetadata, ModelPersistence

__all__ = [
    # Core engine
    "LearningEngine",
    # Feature extraction
    "FeatureConfig",
    "FeatureExtractor",
    # ML models
    "BaseMLModel",
    "RandomForestModel",
    "GradientBoostingModel",
    "HistGradientBoostingModel",
    "ModelType",
    "TrainingConfig",
    "TrainingResult",
    "PredictionResult",
    "create_model",
    # Persistence
    "ModelPersistence",
    "ModelMetadata",
]