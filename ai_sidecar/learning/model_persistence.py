"""
Model Persistence Layer for Learning Engine.

Handles saving, loading, and versioning of trained ML models with
thread-safe access and comprehensive metadata tracking.
"""

import hashlib
import json
import os
import threading
from datetime import datetime
from pathlib import Path
from pickle import dump as pickle_dump
from pickle import load as pickle_load
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field

from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)


class ModelMetadata(BaseModel):
    """Metadata for a trained model."""
    
    model_id: str
    model_name: str
    model_type: str  # random_forest, gradient_boosting, neural_net
    version: int = 1
    created_at: datetime = Field(default_factory=datetime.now)
    updated_at: datetime = Field(default_factory=datetime.now)
    
    # Training info
    training_samples: int = 0
    feature_names: List[str] = Field(default_factory=list)
    feature_count: int = 0
    target_classes: List[str] = Field(default_factory=list)
    
    # Performance metrics
    accuracy: float = 0.0
    precision: float = 0.0
    recall: float = 0.0
    f1_score: float = 0.0
    training_loss: float = 0.0
    validation_loss: float = 0.0
    
    # Hyperparameters
    hyperparameters: Dict[str, Any] = Field(default_factory=dict)
    
    # File paths
    model_file: str = ""
    metadata_file: str = ""
    
    # Hash for integrity verification
    model_hash: str = ""


class ModelPersistence:
    """
    Thread-safe model persistence layer.
    
    Handles saving, loading, and versioning of ML models with
    comprehensive metadata tracking and integrity verification.
    """
    
    def __init__(self, models_dir: str = "data/learning/models"):
        """
        Initialize model persistence.
        
        Args:
            models_dir: Directory for storing models
        """
        self.models_dir = Path(models_dir)
        self.models_dir.mkdir(parents=True, exist_ok=True)
        
        # Thread-safe locks
        self._save_lock = threading.Lock()
        self._load_lock = threading.Lock()
        
        # Model cache for loaded models
        self._model_cache: Dict[str, Any] = {}
        self._metadata_cache: Dict[str, ModelMetadata] = {}
        self._cache_lock = threading.Lock()
        
        logger.info(
            "model_persistence_initialized",
            models_dir=str(self.models_dir)
        )
    
    def _generate_model_id(self, model_name: str, model_type: str) -> str:
        """Generate unique model ID."""
        timestamp = datetime.now().isoformat()
        content = f"{model_name}:{model_type}:{timestamp}"
        return hashlib.md5(content.encode()).hexdigest()[:12]
    
    def _compute_model_hash(self, model_path: Path) -> str:
        """Compute SHA256 hash of model file for integrity."""
        sha256 = hashlib.sha256()
        with open(model_path, "rb") as f:
            for chunk in iter(lambda: f.read(8192), b""):
                sha256.update(chunk)
        return sha256.hexdigest()
    
    def _get_model_dir(self, model_name: str) -> Path:
        """Get directory for a specific model."""
        model_dir = self.models_dir / model_name
        model_dir.mkdir(parents=True, exist_ok=True)
        return model_dir
    
    def _get_latest_version(self, model_name: str) -> int:
        """Get latest version number for a model."""
        model_dir = self._get_model_dir(model_name)
        versions = []
        
        for f in model_dir.glob("*.metadata.json"):
            try:
                with open(f, "r") as fp:
                    metadata = json.load(fp)
                    versions.append(metadata.get("version", 0))
            except (json.JSONDecodeError, KeyError):
                continue
        
        return max(versions) if versions else 0
    
    def save_model(
        self,
        model: Any,
        model_name: str,
        model_type: str,
        metadata: Optional[Dict[str, Any]] = None,
        increment_version: bool = True
    ) -> ModelMetadata:
        """
        Save a trained model to disk with metadata.
        
        Args:
            model: Trained sklearn model object
            model_name: Name identifier for the model
            model_type: Type of model (random_forest, gradient_boosting, etc.)
            metadata: Additional metadata to store
            increment_version: Whether to increment version number
            
        Returns:
            ModelMetadata with save details
        """
        with self._save_lock:
            try:
                model_dir = self._get_model_dir(model_name)
                
                # Determine version
                if increment_version:
                    version = self._get_latest_version(model_name) + 1
                else:
                    version = max(1, self._get_latest_version(model_name))
                
                # Generate file paths
                model_id = self._generate_model_id(model_name, model_type)
                model_filename = f"{model_name}_v{version}.pkl"
                metadata_filename = f"{model_name}_v{version}.metadata.json"
                
                model_path = model_dir / model_filename
                metadata_path = model_dir / metadata_filename
                
                # Save model using pickle with protocol 5 for efficiency
                logger.debug(
                    "saving_model",
                    model_name=model_name,
                    version=version,
                    path=str(model_path)
                )
                
                with open(model_path, "wb") as f:
                    pickle_dump(model, f, protocol=5)
                
                # Compute hash for integrity
                model_hash = self._compute_model_hash(model_path)
                
                # Build metadata
                meta = metadata or {}
                model_metadata = ModelMetadata(
                    model_id=model_id,
                    model_name=model_name,
                    model_type=model_type,
                    version=version,
                    training_samples=meta.get("training_samples", 0),
                    feature_names=meta.get("feature_names", []),
                    feature_count=meta.get("feature_count", 0),
                    target_classes=meta.get("target_classes", []),
                    accuracy=meta.get("accuracy", 0.0),
                    precision=meta.get("precision", 0.0),
                    recall=meta.get("recall", 0.0),
                    f1_score=meta.get("f1_score", 0.0),
                    training_loss=meta.get("training_loss", 0.0),
                    validation_loss=meta.get("validation_loss", 0.0),
                    hyperparameters=meta.get("hyperparameters", {}),
                    model_file=str(model_path),
                    metadata_file=str(metadata_path),
                    model_hash=model_hash
                )
                
                # Save metadata
                with open(metadata_path, "w") as f:
                    json.dump(model_metadata.model_dump(mode="json"), f, indent=2, default=str)
                
                # Update cache
                with self._cache_lock:
                    cache_key = f"{model_name}:v{version}"
                    self._model_cache[cache_key] = model
                    self._metadata_cache[cache_key] = model_metadata
                
                logger.info(
                    "model_saved",
                    model_name=model_name,
                    model_type=model_type,
                    version=version,
                    path=str(model_path),
                    hash=model_hash[:16]
                )
                
                return model_metadata
                
            except Exception as e:
                logger.error(
                    "model_save_failed",
                    model_name=model_name,
                    error=str(e)
                )
                raise
    
    def load_model(
        self,
        model_name: str,
        version: Optional[int] = None,
        verify_integrity: bool = True
    ) -> tuple[Any, ModelMetadata]:
        """
        Load a trained model from disk.
        
        Args:
            model_name: Name identifier for the model
            version: Specific version to load (None for latest)
            verify_integrity: Whether to verify model hash
            
        Returns:
            Tuple of (model object, metadata)
        """
        with self._load_lock:
            try:
                # Determine version
                if version is None:
                    version = self._get_latest_version(model_name)
                    if version == 0:
                        raise FileNotFoundError(
                            f"No models found for '{model_name}'"
                        )
                
                cache_key = f"{model_name}:v{version}"
                
                # Check cache first
                with self._cache_lock:
                    if cache_key in self._model_cache:
                        logger.debug(
                            "model_loaded_from_cache",
                            model_name=model_name,
                            version=version
                        )
                        return (
                            self._model_cache[cache_key],
                            self._metadata_cache[cache_key]
                        )
                
                model_dir = self._get_model_dir(model_name)
                model_path = model_dir / f"{model_name}_v{version}.pkl"
                metadata_path = model_dir / f"{model_name}_v{version}.metadata.json"
                
                if not model_path.exists():
                    raise FileNotFoundError(
                        f"Model file not found: {model_path}"
                    )
                
                if not metadata_path.exists():
                    raise FileNotFoundError(
                        f"Metadata file not found: {metadata_path}"
                    )
                
                # Load metadata
                with open(metadata_path, "r") as f:
                    meta_dict = json.load(f)
                    # Handle datetime fields
                    if "created_at" in meta_dict and isinstance(meta_dict["created_at"], str):
                        meta_dict["created_at"] = datetime.fromisoformat(meta_dict["created_at"])
                    if "updated_at" in meta_dict and isinstance(meta_dict["updated_at"], str):
                        meta_dict["updated_at"] = datetime.fromisoformat(meta_dict["updated_at"])
                    model_metadata = ModelMetadata(**meta_dict)
                
                # Verify integrity if requested
                if verify_integrity and model_metadata.model_hash:
                    current_hash = self._compute_model_hash(model_path)
                    if current_hash != model_metadata.model_hash:
                        raise ValueError(
                            f"Model integrity check failed for {model_name} v{version}"
                        )
                
                # Load model
                logger.debug(
                    "loading_model",
                    model_name=model_name,
                    version=version,
                    path=str(model_path)
                )
                
                with open(model_path, "rb") as f:
                    model = pickle_load(f)
                
                # Update cache
                with self._cache_lock:
                    self._model_cache[cache_key] = model
                    self._metadata_cache[cache_key] = model_metadata
                
                logger.info(
                    "model_loaded",
                    model_name=model_name,
                    model_type=model_metadata.model_type,
                    version=version,
                    accuracy=model_metadata.accuracy
                )
                
                return model, model_metadata
                
            except Exception as e:
                logger.error(
                    "model_load_failed",
                    model_name=model_name,
                    version=version,
                    error=str(e)
                )
                raise
    
    def model_exists(self, model_name: str, version: Optional[int] = None) -> bool:
        """Check if a model exists."""
        if version is None:
            version = self._get_latest_version(model_name)
        
        if version == 0:
            return False
        
        model_dir = self._get_model_dir(model_name)
        model_path = model_dir / f"{model_name}_v{version}.pkl"
        return model_path.exists()
    
    def list_models(self) -> List[Dict[str, Any]]:
        """List all available models with their versions."""
        models = []
        
        for model_dir in self.models_dir.iterdir():
            if model_dir.is_dir():
                model_name = model_dir.name
                versions = []
                
                for metadata_file in model_dir.glob("*.metadata.json"):
                    try:
                        with open(metadata_file, "r") as f:
                            meta = json.load(f)
                            versions.append({
                                "version": meta.get("version", 0),
                                "accuracy": meta.get("accuracy", 0.0),
                                "created_at": meta.get("created_at"),
                                "model_type": meta.get("model_type")
                            })
                    except (json.JSONDecodeError, KeyError):
                        continue
                
                if versions:
                    versions.sort(key=lambda x: x["version"], reverse=True)
                    models.append({
                        "model_name": model_name,
                        "latest_version": versions[0]["version"],
                        "versions": versions
                    })
        
        return models
    
    def delete_model(self, model_name: str, version: Optional[int] = None) -> bool:
        """
        Delete a model version or all versions.
        
        Args:
            model_name: Name of model to delete
            version: Specific version to delete (None for all)
            
        Returns:
            True if deletion successful
        """
        try:
            model_dir = self._get_model_dir(model_name)
            
            if version is not None:
                # Delete specific version
                model_path = model_dir / f"{model_name}_v{version}.pkl"
                metadata_path = model_dir / f"{model_name}_v{version}.metadata.json"
                
                if model_path.exists():
                    os.remove(model_path)
                if metadata_path.exists():
                    os.remove(metadata_path)
                
                # Clear from cache
                cache_key = f"{model_name}:v{version}"
                with self._cache_lock:
                    self._model_cache.pop(cache_key, None)
                    self._metadata_cache.pop(cache_key, None)
            else:
                # Delete all versions
                import shutil
                shutil.rmtree(model_dir, ignore_errors=True)
                
                # Clear all cached versions
                with self._cache_lock:
                    keys_to_remove = [
                        k for k in self._model_cache.keys()
                        if k.startswith(f"{model_name}:")
                    ]
                    for key in keys_to_remove:
                        self._model_cache.pop(key, None)
                        self._metadata_cache.pop(key, None)
            
            logger.info(
                "model_deleted",
                model_name=model_name,
                version=version
            )
            return True
            
        except Exception as e:
            logger.error(
                "model_delete_failed",
                model_name=model_name,
                version=version,
                error=str(e)
            )
            return False
    
    def clear_cache(self) -> None:
        """Clear the in-memory model cache."""
        with self._cache_lock:
            self._model_cache.clear()
            self._metadata_cache.clear()
        logger.debug("model_cache_cleared")
    
    def get_cache_stats(self) -> Dict[str, int]:
        """Get cache statistics."""
        with self._cache_lock:
            return {
                "models_cached": len(self._model_cache),
                "metadata_cached": len(self._metadata_cache)
            }