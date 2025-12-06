"""
Feature Extraction for Decision Context.

Converts game state and decision context into feature vectors
suitable for ML model training and inference.
"""

from datetime import datetime
from typing import Any, Dict, List, Optional, Tuple

import numpy as np
from pydantic import BaseModel, Field

from ai_sidecar.memory.decision_models import DecisionContext, DecisionRecord
from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)


class FeatureConfig(BaseModel):
    """Configuration for feature extraction."""
    
    # Numerical features to extract from game state
    numerical_features: List[str] = Field(default_factory=lambda: [
        "hp_percent", "sp_percent", "weight_percent",
        "base_level", "job_level", "zeny",
        "str", "agi", "vit", "int", "dex", "luk",
        "atk", "def", "matk", "mdef", "hit", "flee",
        "enemies_nearby", "allies_nearby", "distance_to_target",
        "time_of_day_hour", "x_coord", "y_coord"
    ])
    
    # Categorical features to one-hot encode
    categorical_features: List[str] = Field(default_factory=lambda: [
        "decision_type", "current_map", "job_class",
        "target_type", "last_action"
    ])
    
    # Max categories for each categorical feature (for consistent encoding)
    max_categories: Dict[str, int] = Field(default_factory=lambda: {
        "decision_type": 10,
        "current_map": 100,
        "job_class": 50,
        "target_type": 20,
        "last_action": 30
    })
    
    # Feature scaling
    normalize: bool = True
    clip_outliers: bool = True
    outlier_percentile: float = 99.0


class FeatureExtractor:
    """
    Extracts ML-ready features from decision contexts.
    
    Handles numerical and categorical features with proper
    encoding, normalization, and missing value handling.
    """
    
    def __init__(self, config: Optional[FeatureConfig] = None):
        """
        Initialize feature extractor.
        
        Args:
            config: Feature extraction configuration
        """
        self.config = config or FeatureConfig()
        
        # Category mappings for consistent encoding
        self._category_mappings: Dict[str, Dict[str, int]] = {}
        
        # Feature statistics for normalization
        self._feature_stats: Dict[str, Dict[str, float]] = {}
        
        # Track feature names for model interpretation
        self._feature_names: List[str] = []
        self._is_fitted = False
        
        logger.info(
            "feature_extractor_initialized",
            numerical_features=len(self.config.numerical_features),
            categorical_features=len(self.config.categorical_features)
        )
    
    def fit(self, records: List[DecisionRecord]) -> "FeatureExtractor":
        """
        Fit feature extractor on training data.
        
        Learns category mappings and feature statistics.
        
        Args:
            records: List of decision records to fit on
            
        Returns:
            Self for chaining
        """
        if not records:
            logger.warning("fit_called_with_empty_records")
            return self
        
        logger.info("fitting_feature_extractor", n_records=len(records))
        
        # Collect raw feature values
        numerical_values: Dict[str, List[float]] = {
            f: [] for f in self.config.numerical_features
        }
        categorical_values: Dict[str, set] = {
            f: set() for f in self.config.categorical_features
        }
        
        for record in records:
            features = self._extract_raw_features(record)
            
            # Collect numerical values
            for feat_name in self.config.numerical_features:
                if feat_name in features and features[feat_name] is not None:
                    numerical_values[feat_name].append(float(features[feat_name]))
            
            # Collect categorical values
            for feat_name in self.config.categorical_features:
                if feat_name in features and features[feat_name] is not None:
                    categorical_values[feat_name].add(str(features[feat_name]))
        
        # Compute numerical statistics for normalization
        for feat_name, values in numerical_values.items():
            if values:
                values_arr = np.array(values)
                self._feature_stats[feat_name] = {
                    "mean": float(np.mean(values_arr)),
                    "std": float(np.std(values_arr)) or 1.0,  # Avoid division by zero
                    "min": float(np.min(values_arr)),
                    "max": float(np.max(values_arr)),
                    "p01": float(np.percentile(values_arr, 1)),
                    "p99": float(np.percentile(values_arr, 99))
                }
            else:
                self._feature_stats[feat_name] = {
                    "mean": 0.0, "std": 1.0, "min": 0.0, "max": 1.0,
                    "p01": 0.0, "p99": 1.0
                }
        
        # Build category mappings
        for feat_name, values in categorical_values.items():
            max_cats = self.config.max_categories.get(feat_name, 50)
            sorted_values = sorted(values)[:max_cats - 1]  # Leave room for unknown
            self._category_mappings[feat_name] = {
                v: i for i, v in enumerate(sorted_values)
            }
            # Add unknown category
            self._category_mappings[feat_name]["__unknown__"] = len(sorted_values)
        
        # Build feature names list
        self._feature_names = []
        for feat_name in self.config.numerical_features:
            self._feature_names.append(feat_name)
        
        for feat_name in self.config.categorical_features:
            n_cats = len(self._category_mappings.get(feat_name, {}))
            for i in range(n_cats):
                self._feature_names.append(f"{feat_name}_{i}")
        
        self._is_fitted = True
        
        logger.info(
            "feature_extractor_fitted",
            total_features=len(self._feature_names),
            numerical=len(self.config.numerical_features),
            categorical_encoded=sum(
                len(m) for m in self._category_mappings.values()
            )
        )
        
        return self
    
    def _extract_raw_features(self, record: DecisionRecord) -> Dict[str, Any]:
        """
        Extract raw feature values from a decision record.
        
        Args:
            record: Decision record to extract features from
            
        Returns:
            Dictionary of feature name to raw value
        """
        features: Dict[str, Any] = {}
        
        # Get context data
        context = record.context
        game_state = context.game_state_snapshot
        
        # Extract numerical features from game state
        features["hp_percent"] = game_state.get("hp_percent", 100.0)
        features["sp_percent"] = game_state.get("sp_percent", 100.0)
        features["weight_percent"] = game_state.get("weight_percent", 0.0)
        features["base_level"] = game_state.get("base_level", 1)
        features["job_level"] = game_state.get("job_level", 1)
        features["zeny"] = game_state.get("zeny", 0)
        
        # Stats
        stats = game_state.get("stats", {})
        features["str"] = stats.get("str", 1)
        features["agi"] = stats.get("agi", 1)
        features["vit"] = stats.get("vit", 1)
        features["int"] = stats.get("int", 1)
        features["dex"] = stats.get("dex", 1)
        features["luk"] = stats.get("luk", 1)
        
        # Combat stats
        features["atk"] = game_state.get("atk", 0)
        features["def"] = game_state.get("def", 0)
        features["matk"] = game_state.get("matk", 0)
        features["mdef"] = game_state.get("mdef", 0)
        features["hit"] = game_state.get("hit", 0)
        features["flee"] = game_state.get("flee", 0)
        
        # Environmental features
        features["enemies_nearby"] = game_state.get("enemies_nearby", 0)
        features["allies_nearby"] = game_state.get("allies_nearby", 0)
        features["distance_to_target"] = game_state.get("distance_to_target", 0)
        
        # Position
        pos = game_state.get("position", {})
        features["x_coord"] = pos.get("x", 0)
        features["y_coord"] = pos.get("y", 0)
        
        # Time features
        features["time_of_day_hour"] = datetime.now().hour
        
        # Categorical features
        features["decision_type"] = record.decision_type
        features["current_map"] = game_state.get("map", "unknown")
        features["job_class"] = game_state.get("job_class", "novice")
        features["target_type"] = game_state.get("target_type", "none")
        features["last_action"] = game_state.get("last_action", "idle")
        
        return features
    
    def transform(
        self,
        records: List[DecisionRecord]
    ) -> Tuple[np.ndarray, List[str]]:
        """
        Transform decision records to feature matrix.
        
        Args:
            records: List of decision records to transform
            
        Returns:
            Tuple of (feature matrix, feature names)
        """
        if not self._is_fitted:
            logger.warning("transforming_without_fit, using defaults")
            self.fit(records)
        
        if not records:
            return np.array([]), self._feature_names
        
        feature_vectors = []
        
        for record in records:
            vector = self._transform_single(record)
            feature_vectors.append(vector)
        
        X = np.array(feature_vectors)
        
        logger.debug(
            "features_transformed",
            n_samples=len(records),
            n_features=X.shape[1] if len(X.shape) > 1 else 0
        )
        
        return X, self._feature_names
    
    def _transform_single(self, record: DecisionRecord) -> np.ndarray:
        """
        Transform a single decision record to feature vector.
        
        Args:
            record: Decision record to transform
            
        Returns:
            Feature vector as numpy array
        """
        raw_features = self._extract_raw_features(record)
        vector_parts = []
        
        # Process numerical features
        for feat_name in self.config.numerical_features:
            value = raw_features.get(feat_name, 0.0)
            
            if value is None:
                value = 0.0
            else:
                value = float(value)
            
            # Normalize if configured
            if self.config.normalize and feat_name in self._feature_stats:
                stats = self._feature_stats[feat_name]
                
                # Clip outliers
                if self.config.clip_outliers:
                    value = np.clip(value, stats["p01"], stats["p99"])
                
                # Z-score normalization
                value = (value - stats["mean"]) / stats["std"]
            
            vector_parts.append(value)
        
        # Process categorical features (one-hot encoding)
        for feat_name in self.config.categorical_features:
            value = str(raw_features.get(feat_name, "__unknown__"))
            mapping = self._category_mappings.get(feat_name, {})
            n_categories = len(mapping)
            
            if n_categories == 0:
                continue
            
            # Create one-hot vector
            one_hot = np.zeros(n_categories)
            idx = mapping.get(value, mapping.get("__unknown__", 0))
            one_hot[idx] = 1.0
            
            vector_parts.extend(one_hot.tolist())
        
        return np.array(vector_parts)
    
    def fit_transform(
        self,
        records: List[DecisionRecord]
    ) -> Tuple[np.ndarray, List[str]]:
        """
        Fit and transform in one step.
        
        Args:
            records: Decision records to fit and transform
            
        Returns:
            Tuple of (feature matrix, feature names)
        """
        return self.fit(records).transform(records)
    
    def extract_labels(
        self,
        records: List[DecisionRecord],
        label_type: str = "success"
    ) -> Tuple[np.ndarray, List[str]]:
        """
        Extract labels from decision records.
        
        Args:
            records: Decision records with outcomes
            label_type: Type of label to extract
                - "success": Binary success/failure
                - "reward": Continuous reward signal
                - "action": Action taken (for classification)
            
        Returns:
            Tuple of (labels array, label names)
        """
        labels = []
        label_names: List[str] = []
        
        for record in records:
            if label_type == "success":
                if record.outcome:
                    labels.append(1 if record.outcome.success else 0)
                else:
                    labels.append(0)  # No outcome = failure
                label_names = ["failure", "success"]
                
            elif label_type == "reward":
                if record.outcome:
                    labels.append(record.outcome.reward_signal)
                else:
                    labels.append(0.0)
                label_names = ["reward_signal"]
                
            elif label_type == "action":
                action = record.action_taken.get("action", "unknown")
                labels.append(action)
                
        y = np.array(labels)
        
        logger.debug(
            "labels_extracted",
            label_type=label_type,
            n_samples=len(labels),
            unique_labels=len(set(labels)) if labels else 0
        )
        
        return y, label_names
    
    def get_feature_names(self) -> List[str]:
        """Get list of feature names."""
        return self._feature_names.copy()
    
    def get_feature_count(self) -> int:
        """Get total number of features."""
        return len(self._feature_names)
    
    def get_feature_importance_names(
        self,
        importances: np.ndarray
    ) -> List[Tuple[str, float]]:
        """
        Get feature names with their importances.
        
        Args:
            importances: Array of feature importance values
            
        Returns:
            List of (feature_name, importance) tuples, sorted by importance
        """
        if len(importances) != len(self._feature_names):
            logger.warning(
                "feature_importance_mismatch",
                expected=len(self._feature_names),
                got=len(importances)
            )
            return []
        
        pairs = list(zip(self._feature_names, importances))
        pairs.sort(key=lambda x: abs(x[1]), reverse=True)
        return pairs
    
    def to_dict(self) -> Dict[str, Any]:
        """Serialize feature extractor state to dictionary."""
        return {
            "config": self.config.model_dump(),
            "category_mappings": self._category_mappings,
            "feature_stats": self._feature_stats,
            "feature_names": self._feature_names,
            "is_fitted": self._is_fitted
        }
    
    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "FeatureExtractor":
        """
        Deserialize feature extractor from dictionary.
        
        Args:
            data: Serialized state dictionary
            
        Returns:
            Reconstructed FeatureExtractor
        """
        config = FeatureConfig(**data.get("config", {}))
        extractor = cls(config)
        extractor._category_mappings = data.get("category_mappings", {})
        extractor._feature_stats = data.get("feature_stats", {})
        extractor._feature_names = data.get("feature_names", [])
        extractor._is_fitted = data.get("is_fitted", False)
        return extractor