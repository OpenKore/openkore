"""
AI Sidecar - God-Tier RO AI System

This package provides the Python AI sidecar that connects to OpenKore via ZeroMQ IPC.
It receives game state updates and returns AI decisions for character control.

Architecture:
- IPC Layer: ZeroMQ REP socket for receiving state and responding with decisions
- Core Layer: State management, decision engine, and tick processing
- Protocol Layer: Message definitions and JSON schemas
- Utils Layer: Logging and helper utilities

IMPORTANT: To avoid circular import dependencies, configuration is NOT exported
from this module. Import settings directly from the config module:

    from ai_sidecar.config import get_settings, Settings

This breaks the circular chain:
    __init__.py -> config.py -> utils -> logging.py -> config.py
"""

__version__ = "0.1.0"
__author__ = "AI-MMORPG Team"

# Note: get_settings is NOT exported here to avoid circular imports.
# Users should import directly: from ai_sidecar.config import get_settings
__all__ = ["__version__", "__author__"]