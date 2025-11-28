"""
LLM integration for AI Sidecar.

Supports multiple LLM providers with fallback chains:
- OpenAI (GPT-4o-mini, GPT-4)
- Azure OpenAI
- DeepSeek
- Claude (Anthropic)
"""

from .providers import (
    LLMMessage,
    LLMResponse,
    LLMProvider,
    OpenAIProvider,
    AzureOpenAIProvider,
    DeepSeekProvider,
    ClaudeProvider,
)
from .manager import LLMManager

__all__ = [
    "LLMMessage",
    "LLMResponse",
    "LLMProvider",
    "OpenAIProvider",
    "AzureOpenAIProvider",
    "DeepSeekProvider",
    "ClaudeProvider",
    "LLMManager",
]