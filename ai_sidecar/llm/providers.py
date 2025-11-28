"""
LLM Provider implementations.

Supports multiple LLM providers with unified interface.
"""

import time
from abc import ABC, abstractmethod
from typing import List, Literal, Optional

from pydantic import BaseModel

from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)


class LLMMessage(BaseModel):
    """Message for LLM conversation."""
    
    role: Literal["system", "user", "assistant"]
    content: str


class LLMResponse(BaseModel):
    """Response from LLM."""
    
    content: str
    provider: str
    model: str
    tokens_used: int = 0
    latency_ms: float = 0


class LLMProvider(ABC):
    """Abstract base for LLM providers."""
    
    provider_name: str = "base"
    
    @abstractmethod
    async def complete(
        self, messages: List[LLMMessage], max_tokens: int = 500, temperature: float = 0.7
    ) -> Optional[LLMResponse]:
        """Generate completion."""
        pass
    
    @abstractmethod
    async def is_available(self) -> bool:
        """Check if provider is available."""
        pass


class OpenAIProvider(LLMProvider):
    """OpenAI SDK provider."""
    
    provider_name = "openai"
    
    def __init__(self, api_key: str, model: str = "gpt-4o-mini"):
        """
        Initialize OpenAI provider.
        
        Args:
            api_key: OpenAI API key
            model: Model to use (default: gpt-4o-mini)
        """
        self.api_key = api_key
        self.model = model
        self._client = None
    
    async def _get_client(self):
        """Get or create OpenAI client."""
        if not self._client:
            try:
                import openai
                
                self._client = openai.AsyncOpenAI(api_key=self.api_key)
            except ImportError:
                logger.error("openai package not installed")
                return None
        return self._client
    
    async def complete(
        self, messages: List[LLMMessage], max_tokens: int = 500, temperature: float = 0.7
    ) -> Optional[LLMResponse]:
        """Generate completion using OpenAI."""
        try:
            start = time.time()
            
            client = await self._get_client()
            if not client:
                return None
            
            response = await client.chat.completions.create(
                model=self.model,
                messages=[m.model_dump() for m in messages],
                max_tokens=max_tokens,
                temperature=temperature,
            )
            
            latency = (time.time() - start) * 1000
            
            return LLMResponse(
                content=response.choices[0].message.content,
                provider=self.provider_name,
                model=self.model,
                tokens_used=response.usage.total_tokens,
                latency_ms=latency,
            )
        except Exception as e:
            logger.error("openai_completion_failed", error=str(e))
            return None
    
    async def is_available(self) -> bool:
        """Check if OpenAI is available."""
        return self.api_key is not None


class AzureOpenAIProvider(LLMProvider):
    """Azure OpenAI SDK provider."""
    
    provider_name = "azure"
    
    def __init__(
        self,
        api_key: str,
        endpoint: str,
        deployment: str,
        api_version: str = "2024-02-01",
    ):
        """
        Initialize Azure OpenAI provider.
        
        Args:
            api_key: Azure OpenAI API key
            endpoint: Azure endpoint URL
            deployment: Deployment name
            api_version: API version
        """
        self.api_key = api_key
        self.endpoint = endpoint
        self.deployment = deployment
        self.api_version = api_version
        self._client = None
    
    async def _get_client(self):
        """Get or create Azure OpenAI client."""
        if not self._client:
            try:
                import openai
                
                self._client = openai.AsyncAzureOpenAI(
                    api_key=self.api_key,
                    api_version=self.api_version,
                    azure_endpoint=self.endpoint,
                )
            except ImportError:
                logger.error("openai package not installed")
                return None
        return self._client
    
    async def complete(
        self, messages: List[LLMMessage], max_tokens: int = 500, temperature: float = 0.7
    ) -> Optional[LLMResponse]:
        """Generate completion using Azure OpenAI."""
        try:
            start = time.time()
            
            client = await self._get_client()
            if not client:
                return None
            
            response = await client.chat.completions.create(
                model=self.deployment,
                messages=[m.model_dump() for m in messages],
                max_tokens=max_tokens,
                temperature=temperature,
            )
            
            latency = (time.time() - start) * 1000
            
            return LLMResponse(
                content=response.choices[0].message.content,
                provider=self.provider_name,
                model=self.deployment,
                tokens_used=response.usage.total_tokens,
                latency_ms=latency,
            )
        except Exception as e:
            logger.error("azure_completion_failed", error=str(e))
            return None
    
    async def is_available(self) -> bool:
        """Check if Azure OpenAI is available."""
        return self.api_key is not None and self.endpoint is not None


class DeepSeekProvider(LLMProvider):
    """DeepSeek SDK provider."""
    
    provider_name = "deepseek"
    
    def __init__(self, api_key: str, model: str = "deepseek-chat"):
        """
        Initialize DeepSeek provider.
        
        Args:
            api_key: DeepSeek API key
            model: Model to use
        """
        self.api_key = api_key
        self.model = model
        self.base_url = "https://api.deepseek.com/v1"
    
    async def complete(
        self, messages: List[LLMMessage], max_tokens: int = 500, temperature: float = 0.7
    ) -> Optional[LLMResponse]:
        """Generate completion using DeepSeek."""
        try:
            import httpx
            
            start = time.time()
            
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.base_url}/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self.api_key}",
                        "Content-Type": "application/json",
                    },
                    json={
                        "model": self.model,
                        "messages": [m.model_dump() for m in messages],
                        "max_tokens": max_tokens,
                        "temperature": temperature,
                    },
                    timeout=30.0,
                )
                response.raise_for_status()
                data = response.json()
            
            latency = (time.time() - start) * 1000
            
            return LLMResponse(
                content=data["choices"][0]["message"]["content"],
                provider=self.provider_name,
                model=self.model,
                tokens_used=data.get("usage", {}).get("total_tokens", 0),
                latency_ms=latency,
            )
        except ImportError:
            logger.error("httpx package not installed")
            return None
        except Exception as e:
            logger.error("deepseek_completion_failed", error=str(e))
            return None
    
    async def is_available(self) -> bool:
        """Check if DeepSeek is available."""
        return self.api_key is not None


class ClaudeProvider(LLMProvider):
    """Anthropic Claude SDK provider."""
    
    provider_name = "claude"
    
    def __init__(self, api_key: str, model: str = "claude-3-haiku-20240307"):
        """
        Initialize Claude provider.
        
        Args:
            api_key: Anthropic API key
            model: Model to use
        """
        self.api_key = api_key
        self.model = model
        self._client = None
    
    async def _get_client(self):
        """Get or create Anthropic client."""
        if not self._client:
            try:
                import anthropic
                
                self._client = anthropic.AsyncAnthropic(api_key=self.api_key)
            except ImportError:
                logger.error("anthropic package not installed")
                return None
        return self._client
    
    async def complete(
        self, messages: List[LLMMessage], max_tokens: int = 500, temperature: float = 0.7
    ) -> Optional[LLMResponse]:
        """Generate completion using Claude."""
        try:
            start = time.time()
            
            client = await self._get_client()
            if not client:
                return None
            
            # Extract system message
            system = None
            user_messages = []
            for m in messages:
                if m.role == "system":
                    system = m.content
                else:
                    user_messages.append({"role": m.role, "content": m.content})
            
            response = await client.messages.create(
                model=self.model,
                max_tokens=max_tokens,
                system=system,
                messages=user_messages,
            )
            
            latency = (time.time() - start) * 1000
            
            return LLMResponse(
                content=response.content[0].text,
                provider=self.provider_name,
                model=self.model,
                tokens_used=response.usage.input_tokens + response.usage.output_tokens,
                latency_ms=latency,
            )
        except Exception as e:
            logger.error("claude_completion_failed", error=str(e))
            return None
    
    async def is_available(self) -> bool:
        """Check if Claude is available."""
        return self.api_key is not None