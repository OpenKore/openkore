"""
Human Mimicry and Anti-Detection System for OpenKore AI.

This package provides comprehensive anti-detection capabilities through:
- Human-like timing with statistical distributions
- Natural movement patterns with Bezier curves
- Random behavior injection
- Session lifecycle management
- Chat humanization with typos and delays
- Pattern detection and breaking
- Unified anti-detection coordination

Usage:
    from mimicry import AntiDetectionCoordinator
    
    coordinator = AntiDetectionCoordinator(data_dir=Path("./data"))
    
    # Humanize an action
    action = {"action_type": "attack", "target_id": 123}
    humanized = await coordinator.humanize_action(action)
    
    # Check detection risk
    risk_report = await coordinator.assess_detection_risk()
"""

from .anti_detection import (
    AntiDetectionCoordinator,
    AntiDetectionReport,
    DetectionRisk,
)

from .timing import (
    HumanTimingEngine,
    TimingProfile,
    ActionTiming,
    ReactionType,
)

from .movement import (
    MovementHumanizer,
    HumanPath,
    PathPoint,
    MovementPattern,
)

from .randomizer import (
    BehaviorRandomizer,
    RandomBehavior,
    RandomBehaviorPool,
    BehaviorCategory,
)

from .session import (
    HumanSessionManager,
    PlaySession,
    SessionState,
    SessionBehavior,
)

from .chat import (
    HumanChatSimulator,
    ChatResponse,
    ChatContext,
    ChatStyle,
)

from .pattern_breaker import (
    PatternBreaker,
    DetectedPattern,
    PatternType,
)

__all__ = [
    # Main coordinator
    "AntiDetectionCoordinator",
    "AntiDetectionReport",
    "DetectionRisk",
    
    # Timing
    "HumanTimingEngine",
    "TimingProfile",
    "ActionTiming",
    "ReactionType",
    
    # Movement
    "MovementHumanizer",
    "HumanPath",
    "PathPoint",
    "MovementPattern",
    
    # Randomization
    "BehaviorRandomizer",
    "RandomBehavior",
    "RandomBehaviorPool",
    "BehaviorCategory",
    
    # Session
    "HumanSessionManager",
    "PlaySession",
    "SessionState",
    "SessionBehavior",
    
    # Chat
    "HumanChatSimulator",
    "ChatResponse",
    "ChatContext",
    "ChatStyle",
    
    # Pattern breaking
    "PatternBreaker",
    "DetectedPattern",
    "PatternType",
]