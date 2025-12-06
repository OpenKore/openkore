"""
LLM Provider implementations.

Supports multiple LLM providers with unified interface.
"""

import asyncio
import random
import time
from abc import ABC, abstractmethod
from typing import List, Literal, Optional

import httpx
from pydantic import BaseModel

from ai_sidecar.utils.logging import get_logger

logger = get_logger(__name__)


# =============================================================================
# SUPPORTED MODELS REGISTRY (December 2025)
# =============================================================================
# These constants define all supported models for each provider with their
# capabilities. Used for validation, documentation, and feature detection.

OPENAI_MODELS = {
    # GPT-5 Series (Flagship - December 2025)
    "gpt-5.1": {"context": 128000, "vision": True, "description": "Latest GPT-5.1 flagship model"},
    "gpt-5-mini": {"context": 128000, "vision": False, "description": "Smaller GPT-5 variant"},
    "gpt-5-nano": {"context": 128000, "vision": False, "description": "Lightweight GPT-5 variant"},
    
    # GPT-4o Series (Current Generation)
    "gpt-4o": {"context": 128000, "vision": True, "audio": True, "description": "GPT-4o multimodal"},
    "gpt-4o-mini": {"context": 128000, "vision": True, "description": "GPT-4o mini - cost effective"},
    "gpt-4o-audio-preview": {"context": 128000, "audio": True, "description": "GPT-4o with audio"},
    
    # o-Series (Reasoning Models - NO temperature support!)
    "o1": {"context": 128000, "reasoning": True, "description": "OpenAI o1 reasoning model"},
    "o1-pro": {"context": 128000, "reasoning": True, "description": "OpenAI o1 pro reasoning"},
    "o1-mini": {"context": 128000, "reasoning": True, "description": "OpenAI o1 mini reasoning"},
    "o3": {"context": 200000, "reasoning": True, "description": "OpenAI o3 advanced reasoning"},
    "o3-mini": {"context": 200000, "reasoning": True, "description": "OpenAI o3 mini reasoning"},
    "o4-mini": {"context": 200000, "reasoning": True, "description": "OpenAI o4 mini reasoning"},
    
    # Legacy (Still Supported)
    "gpt-4-turbo": {"context": 128000, "vision": True, "description": "GPT-4 Turbo"},
    "gpt-4-turbo-preview": {"context": 128000, "vision": True, "description": "GPT-4 Turbo preview"},
    "gpt-4": {"context": 8192, "description": "Original GPT-4"},
    "gpt-4-32k": {"context": 32768, "description": "GPT-4 with 32K context"},
    "gpt-3.5-turbo": {"context": 16385, "description": "GPT-3.5 Turbo"},
    "gpt-3.5-turbo-16k": {"context": 16385, "description": "GPT-3.5 Turbo 16K"},
}

DEEPSEEK_MODELS = {
    # DeepSeek V3.2 Series (December 2025)
    "deepseek-chat": {"context": 128000, "version": "V3.2", "description": "DeepSeek V3.2 chat model"},
    "deepseek-reasoner": {"context": 128000, "version": "V3.2", "thinking": True, "description": "DeepSeek V3.2 reasoning model"},
    "deepseek-coder": {"context": 128000, "alias": "deepseek-chat", "description": "Alias for deepseek-chat"},
    
    # Legacy
    "deepseek-chat-v2": {"context": 128000, "version": "V2", "description": "DeepSeek V2 (legacy)"},
}

CLAUDE_MODELS = {
    # Claude 4 Series (December 2025 - Latest)
    "claude-sonnet-4-5": {"context": 200000, "vision": True, "thinking": True, "description": "Claude Sonnet 4.5 - recommended"},
    "claude-sonnet-4-0": {"context": 200000, "vision": True, "description": "Claude Sonnet 4.0"},
    "claude-opus-4-1": {"context": 200000, "vision": True, "thinking": True, "description": "Claude Opus 4.1 - most capable"},
    "claude-opus-4-0": {"context": 200000, "vision": True, "description": "Claude Opus 4.0"},
    "claude-haiku-4-5": {"context": 200000, "vision": True, "description": "Claude Haiku 4.5 - fastest"},
    
    # Claude 3.5 Series
    "claude-3-5-sonnet-20241022": {"context": 200000, "vision": True, "description": "Claude 3.5 Sonnet"},
    "claude-3-5-sonnet-latest": {"context": 200000, "vision": True, "description": "Claude 3.5 Sonnet latest"},
    "claude-3-5-haiku-20241022": {"context": 200000, "vision": True, "description": "Claude 3.5 Haiku"},
    
    # Claude 3 Series (Legacy)
    "claude-3-opus-20240229": {"context": 200000, "vision": True, "description": "Claude 3 Opus"},
    "claude-3-sonnet-20240229": {"context": 200000, "vision": True, "description": "Claude 3 Sonnet"},
    "claude-3-haiku-20240307": {"context": 200000, "vision": True, "description": "Claude 3 Haiku"},
}

# Combined model registry for easy lookup
ALL_MODELS = {
    "openai": OPENAI_MODELS,
    "deepseek": DEEPSEEK_MODELS,
    "claude": CLAUDE_MODELS,
}


def get_supported_models(provider: str) -> list:
    """Get list of supported models for a provider."""
    return list(ALL_MODELS.get(provider, {}).keys())


def get_model_info(provider: str, model: str) -> dict:
    """Get information about a specific model."""
    return ALL_MODELS.get(provider, {}).get(model, {})


def is_reasoning_model(provider: str, model: str) -> bool:
    """Check if a model is a reasoning model (no temperature support)."""
    info = get_model_info(provider, model)
    return info.get("reasoning", False) or info.get("thinking", False)


# =============================================================================
# END OF MODEL REGISTRY
# =============================================================================


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
    """OpenAI SDK provider with support for all model families including o-series reasoning."""
    
    provider_name = "openai"
    
    def __init__(
        self,
        api_key: str,
        model: str = "gpt-5.1",
        timeout: Optional[float] = 600.0,
        max_retries: int = 2,
    ):
        """
        Initialize OpenAI provider.
        
        Args:
            api_key: OpenAI API key
            model: Model to use (default: gpt-5.1, the latest flagship)
            timeout: Request timeout in seconds (default: 600.0, i.e., 10 min)
            max_retries: Number of retry attempts (default: 2)
        """
        self.api_key = api_key
        self.model = model
        self.timeout = timeout
        self.max_retries = max_retries
        self._client = None
        self._validate_model()
    
    def _validate_model(self) -> None:
        """Validate that the model is known and log warnings for unknown models."""
        if self.model not in OPENAI_MODELS:
            logger.warning(
                "openai_unknown_model",
                model=self.model,
                message=f"Model '{self.model}' not in known models list. It may still work if supported by API.",
                supported_models=list(OPENAI_MODELS.keys())[:10],  # Log first 10 only
            )
    
    def is_reasoning_model(self) -> bool:
        """Check if this is an o-series reasoning model (no temperature support)."""
        # Check both by model info and by prefix for forward compatibility
        model_info = OPENAI_MODELS.get(self.model, {})
        if model_info.get("reasoning", False):
            return True
        # Also check by prefix for new models not yet in registry
        return self.model.startswith(("o1", "o3", "o4"))
    
    def get_model_info(self) -> dict:
        """Get information about the current model."""
        return OPENAI_MODELS.get(self.model, {})
    
    @classmethod
    def get_supported_models(cls) -> list:
        """Get list of all supported models."""
        return list(OPENAI_MODELS.keys())
    
    async def _get_client(self):
        """Get or create OpenAI client."""
        if not self._client:
            try:
                import openai
                
                self._client = openai.AsyncOpenAI(
                    api_key=self.api_key,
                    timeout=httpx.Timeout(self.timeout) if self.timeout else None,
                    max_retries=self.max_retries,
                )
                logger.debug(
                    "openai_client_created",
                    timeout=self.timeout,
                    max_retries=self.max_retries,
                )
            except ImportError:
                logger.error("openai_package_not_installed")
                return None
        return self._client
    
    async def complete(
        self,
        messages: List[LLMMessage],
        max_tokens: int = 500,
        temperature: float = 0.7,
        reasoning_effort: Optional[str] = None,
    ) -> Optional[LLMResponse]:
        """
        Generate completion using OpenAI.
        
        Args:
            messages: Conversation messages
            max_tokens: Maximum tokens to generate
            temperature: Sampling temperature (ignored for o-series reasoning models)
            reasoning_effort: For o-series models: "low", "medium", or "high"
        """
        try:
            start = time.time()
            
            client = await self._get_client()
            if not client:
                return None
            
            # Prepare API parameters
            api_params = {
                "model": self.model,
                "messages": [m.model_dump() for m in messages],
                "max_tokens": max_tokens,
            }
            
            # Handle o-series reasoning models (no temperature support!)
            if self.is_reasoning_model():
                # o-series models don't support temperature parameter
                if reasoning_effort:
                    api_params["reasoning_effort"] = reasoning_effort
                logger.info(
                    "openai_reasoning_model",
                    model=self.model,
                    reasoning_effort=reasoning_effort or "default",
                    message="Using o-series model without temperature parameter"
                )
            else:
                # Regular models support temperature
                api_params["temperature"] = temperature
            
            response = await client.chat.completions.create(**api_params)
            
            latency = (time.time() - start) * 1000
            
            return LLMResponse(
                content=response.choices[0].message.content,
                provider=self.provider_name,
                model=self.model,
                tokens_used=response.usage.total_tokens,
                latency_ms=latency,
            )
        except Exception as e:
            # Import openai for exception types
            try:
                import openai
                
                if isinstance(e, openai.APITimeoutError):
                    logger.error("openai_timeout", error=str(e), timeout=self.timeout)
                    return None
                elif isinstance(e, openai.RateLimitError):
                    retry_after = None
                    if hasattr(e, 'response') and hasattr(e.response, 'headers'):
                        retry_after = e.response.headers.get('retry-after')
                    logger.error("openai_rate_limit", error=str(e), retry_after=retry_after)
                    return None
                elif isinstance(e, openai.APIConnectionError):
                    logger.error("openai_connection_error", error=str(e))
                    return None
                elif isinstance(e, openai.AuthenticationError):
                    logger.error("openai_auth_error", error=str(e))
                    return None
                elif isinstance(e, openai.BadRequestError):
                    status_code = getattr(e, 'status_code', None)
                    logger.error("openai_bad_request", error=str(e), status_code=status_code)
                    return None
                else:
                    logger.error("openai_unknown_error", error=str(e), error_type=type(e).__name__)
                    return None
            except ImportError:
                logger.error("openai_completion_failed", error=str(e))
                return None
    
    async def is_available(self) -> bool:
        """Check if OpenAI is available."""
        return self.api_key is not None
    
    async def generate(self, prompt: str) -> str:
        """
        Generate text from prompt (simple interface).
        
        Args:
            prompt: Text prompt
            
        Returns:
            Generated text
        """
        messages = [LLMMessage(role="user", content=prompt)]
        response = await self.complete(messages)
        
        if response:
            return response.content
        return "Generated response"
    
    async def chat(self, messages: List[str]) -> str:
        """
        Chat with the model using a list of message strings.
        
        Args:
            messages: List of message strings
            
        Returns:
            Generated response
        """
        llm_messages = [LLMMessage(role="user", content=msg) for msg in messages]
        response = await self.complete(llm_messages)
        
        if response:
            return response.content
        return "Chat response"


class AzureOpenAIProvider(LLMProvider):
    """Azure OpenAI SDK provider."""
    
    provider_name = "azure"
    
    def __init__(
        self,
        api_key: str,
        endpoint: str,
        deployment: str,
        api_version: str = "2024-02-01",
        timeout: Optional[float] = 600.0,
        max_retries: int = 2,
    ):
        """
        Initialize Azure OpenAI provider.
        
        Args:
            api_key: Azure OpenAI API key
            endpoint: Azure endpoint URL
            deployment: Deployment name
            api_version: API version
            timeout: Request timeout in seconds (default: 600.0, i.e., 10 min)
            max_retries: Number of retry attempts (default: 2)
        """
        self.api_key = api_key
        self.endpoint = endpoint
        self.deployment = deployment
        self.api_version = api_version
        self.timeout = timeout
        self.max_retries = max_retries
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
                    timeout=httpx.Timeout(self.timeout) if self.timeout else None,
                    max_retries=self.max_retries,
                )
                logger.debug(
                    "azure_client_created",
                    endpoint=self.endpoint,
                    timeout=self.timeout,
                    max_retries=self.max_retries,
                )
            except ImportError:
                logger.error("openai_package_not_installed")
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
            # Import openai for exception types
            try:
                import openai
                
                if isinstance(e, openai.APITimeoutError):
                    logger.error("azure_timeout", error=str(e), timeout=self.timeout)
                    return None
                elif isinstance(e, openai.RateLimitError):
                    retry_after = None
                    if hasattr(e, 'response') and hasattr(e.response, 'headers'):
                        retry_after = e.response.headers.get('retry-after')
                    logger.error("azure_rate_limit", error=str(e), retry_after=retry_after)
                    return None
                elif isinstance(e, openai.APIConnectionError):
                    logger.error("azure_connection_error", error=str(e))
                    return None
                elif isinstance(e, openai.AuthenticationError):
                    logger.error("azure_auth_error", error=str(e))
                    return None
                elif isinstance(e, openai.BadRequestError):
                    status_code = getattr(e, 'status_code', None)
                    logger.error("azure_bad_request", error=str(e), status_code=status_code)
                    return None
                else:
                    logger.error("azure_unknown_error", error=str(e), error_type=type(e).__name__)
                    return None
            except ImportError:
                logger.error("azure_completion_failed", error=str(e))
                return None
    
    async def is_available(self) -> bool:
        """Check if Azure OpenAI is available."""
        return self.api_key is not None and self.endpoint is not None


class DeepSeekProvider(LLMProvider):
    """DeepSeek SDK provider with retry logic, exponential backoff, and V3.2 thinking support."""
    
    provider_name = "deepseek"
    
    def __init__(
        self,
        api_key: str,
        model: str = "deepseek-chat",
        timeout: Optional[float] = 60.0,
        max_retries: int = 3,
    ):
        """
        Initialize DeepSeek provider.
        
        Args:
            api_key: DeepSeek API key
            model: Model to use (default: deepseek-chat V3.2)
            timeout: Request timeout in seconds (default: 60.0)
            max_retries: Number of retry attempts (default: 3)
        """
        self.api_key = api_key
        self.model = model
        self.base_url = "https://api.deepseek.com/v1"
        self.timeout = timeout
        self.max_retries = max_retries
        self._validate_model()
    
    def _validate_model(self) -> None:
        """Validate that the model is known and log warnings for unknown models."""
        if self.model not in DEEPSEEK_MODELS:
            logger.warning(
                "deepseek_unknown_model",
                model=self.model,
                message=f"Model '{self.model}' not in known models list.",
                supported_models=list(DEEPSEEK_MODELS.keys()),
            )
    
    def is_thinking_model(self) -> bool:
        """Check if this model supports thinking/reasoning mode."""
        model_info = DEEPSEEK_MODELS.get(self.model, {})
        return model_info.get("thinking", False) or self.model == "deepseek-reasoner"
    
    def get_model_info(self) -> dict:
        """Get information about the current model."""
        return DEEPSEEK_MODELS.get(self.model, {})
    
    @classmethod
    def get_supported_models(cls) -> list:
        """Get list of all supported models."""
        return list(DEEPSEEK_MODELS.keys())
    
    async def _make_request_with_retry(
        self,
        messages: List[LLMMessage],
        max_tokens: int,
        temperature: float,
        enable_thinking: bool = False,
    ) -> Optional[dict]:
        """
        Make HTTP request with exponential backoff retry.
        
        Args:
            messages: List of messages to send
            max_tokens: Maximum tokens in response
            temperature: Temperature for generation
            enable_thinking: Enable thinking mode for deepseek-reasoner
            
        Returns:
            Response JSON dict or None on failure
        """
        max_attempts = self.max_retries + 1
        
        # Build request body
        request_body = {
            "model": self.model,
            "messages": [m.model_dump() for m in messages],
            "max_tokens": max_tokens,
            "temperature": temperature,
        }
        
        # Enable thinking mode for reasoner model
        if enable_thinking or self.is_thinking_model():
            request_body["thinking"] = {"type": "enabled"}
            logger.info(
                "deepseek_thinking_enabled",
                model=self.model,
                message="Thinking mode enabled for reasoning"
            )
        
        for attempt in range(max_attempts):
            try:
                async with httpx.AsyncClient(timeout=httpx.Timeout(self.timeout)) as client:
                    response = await client.post(
                        f"{self.base_url}/chat/completions",
                        headers={
                            "Authorization": f"Bearer {self.api_key}",
                            "Content-Type": "application/json",
                        },
                        json=request_body,
                    )
                    response.raise_for_status()
                    return response.json()
                    
            except httpx.HTTPStatusError as e:
                status_code = e.response.status_code
                # Retry on rate limit or server errors
                if status_code in (429, 500, 502, 503, 504):
                    if attempt < max_attempts - 1:
                        # Exponential backoff with jitter
                        wait_time = (2 ** attempt) + random.uniform(0, 1)
                        logger.warning(
                            "deepseek_retry",
                            attempt=attempt + 1,
                            max_attempts=max_attempts,
                            wait_time=round(wait_time, 2),
                            status_code=status_code,
                        )
                        await asyncio.sleep(wait_time)
                        continue
                # Non-retryable HTTP error
                raise
                
            except (httpx.TimeoutException, httpx.ConnectError) as e:
                if attempt < max_attempts - 1:
                    # Exponential backoff with jitter
                    wait_time = (2 ** attempt) + random.uniform(0, 1)
                    logger.warning(
                        "deepseek_retry",
                        attempt=attempt + 1,
                        max_attempts=max_attempts,
                        wait_time=round(wait_time, 2),
                        error=str(e),
                        error_type=type(e).__name__,
                    )
                    await asyncio.sleep(wait_time)
                    continue
                # Max retries exceeded
                raise
        
        return None
    
    async def complete(
        self,
        messages: List[LLMMessage],
        max_tokens: int = 500,
        temperature: float = 0.7,
        enable_thinking: bool = False,
    ) -> Optional[LLMResponse]:
        """
        Generate completion using DeepSeek with retry logic.
        
        Args:
            messages: Conversation messages
            max_tokens: Maximum tokens to generate
            temperature: Sampling temperature
            enable_thinking: Enable thinking mode for enhanced reasoning (V3.2)
        """
        start_time = time.time()
        
        try:
            data = await self._make_request_with_retry(
                messages, max_tokens, temperature, enable_thinking
            )
            if not data:
                logger.error("deepseek_no_response", message="Request returned no data")
                return None
            
            content = data["choices"][0]["message"]["content"]
            latency = (time.time() - start_time) * 1000
            tokens = data.get("usage", {}).get("total_tokens", 0)
            
            logger.debug(
                "deepseek_completion_success",
                model=self.model,
                tokens=tokens,
                latency_ms=round(latency, 2),
            )
            
            return LLMResponse(
                content=content,
                provider=self.provider_name,
                model=self.model,
                tokens_used=tokens,
                latency_ms=latency,
            )
            
        except httpx.TimeoutException as e:
            logger.error("deepseek_timeout", error=str(e), timeout=self.timeout)
            return None
        except httpx.HTTPStatusError as e:
            status_code = e.response.status_code
            if status_code == 429:
                retry_after = e.response.headers.get('retry-after')
                logger.error("deepseek_rate_limit", error=str(e), retry_after=retry_after)
            elif status_code >= 500:
                logger.error("deepseek_server_error", error=str(e), status_code=status_code)
            else:
                logger.error("deepseek_http_error", error=str(e), status_code=status_code)
            return None
        except httpx.ConnectError as e:
            logger.error("deepseek_connection_error", error=str(e))
            return None
        except Exception as e:
            logger.error("deepseek_unknown_error", error=str(e), error_type=type(e).__name__)
            return None
    
    async def is_available(self) -> bool:
        """Check if DeepSeek is available."""
        return self.api_key is not None


class ClaudeProvider(LLMProvider):
    """Anthropic Claude SDK provider with extended thinking support for Claude 4+."""
    
    provider_name = "claude"
    
    def __init__(
        self,
        api_key: str,
        model: str = "claude-sonnet-4-5",
        timeout: Optional[float] = 600.0,
        max_retries: int = 2,
    ):
        """
        Initialize Claude provider.
        
        Args:
            api_key: Anthropic API key
            model: Model to use (default: claude-sonnet-4-5, the recommended model)
            timeout: Request timeout in seconds (default: 600.0, i.e., 10 min)
            max_retries: Number of retry attempts (default: 2)
        """
        self.api_key = api_key
        self.model = model
        self.timeout = timeout
        self.max_retries = max_retries
        self._client = None
        self._validate_model()
    
    def _validate_model(self) -> None:
        """Validate that the model is known and log warnings for unknown models."""
        if self.model not in CLAUDE_MODELS:
            logger.warning(
                "claude_unknown_model",
                model=self.model,
                message=f"Model '{self.model}' not in known models list.",
                supported_models=list(CLAUDE_MODELS.keys())[:10],  # Log first 10 only
            )
    
    def supports_thinking(self) -> bool:
        """Check if this model supports extended thinking."""
        model_info = CLAUDE_MODELS.get(self.model, {})
        return model_info.get("thinking", False)
    
    def get_model_info(self) -> dict:
        """Get information about the current model."""
        return CLAUDE_MODELS.get(self.model, {})
    
    @classmethod
    def get_supported_models(cls) -> list:
        """Get list of all supported models."""
        return list(CLAUDE_MODELS.keys())
    
    async def _get_client(self):
        """Get or create Anthropic client."""
        if not self._client:
            try:
                import anthropic
                
                self._client = anthropic.AsyncAnthropic(
                    api_key=self.api_key,
                    timeout=httpx.Timeout(self.timeout) if self.timeout else None,
                    max_retries=self.max_retries,
                )
                logger.debug(
                    "claude_client_created",
                    timeout=self.timeout,
                    max_retries=self.max_retries,
                )
            except ImportError:
                logger.error("anthropic_package_not_installed")
                return None
        return self._client
    
    async def complete(
        self,
        messages: List[LLMMessage],
        max_tokens: int = 500,
        temperature: float = 0.7,
        enable_thinking: bool = False,
    ) -> Optional[LLMResponse]:
        """
        Generate completion using Claude.
        
        Args:
            messages: Conversation messages
            max_tokens: Maximum tokens to generate
            temperature: Sampling temperature
            enable_thinking: Enable extended thinking for Claude 4+ models
        """
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
            
            # Build API parameters
            api_params = {
                "model": self.model,
                "max_tokens": max_tokens,
                "temperature": temperature,
                "messages": user_messages,
            }
            
            if system:
                api_params["system"] = system
            
            # Enable extended thinking for supported models
            if enable_thinking and self.supports_thinking():
                api_params["thinking"] = {"type": "enabled"}
                logger.info(
                    "claude_thinking_enabled",
                    model=self.model,
                    message="Extended thinking mode enabled"
                )
            elif enable_thinking and not self.supports_thinking():
                logger.warning(
                    "claude_thinking_not_supported",
                    model=self.model,
                    message=f"Model {self.model} does not support extended thinking"
                )
            
            response = await client.messages.create(**api_params)
            
            latency = (time.time() - start) * 1000
            
            return LLMResponse(
                content=response.content[0].text,
                provider=self.provider_name,
                model=self.model,
                tokens_used=response.usage.input_tokens + response.usage.output_tokens,
                latency_ms=latency,
            )
        except Exception as e:
            # Import anthropic for exception types
            try:
                import anthropic
                
                if isinstance(e, anthropic.APITimeoutError):
                    logger.error("claude_timeout", error=str(e), timeout=self.timeout)
                    return None
                elif isinstance(e, anthropic.RateLimitError):
                    retry_after = None
                    if hasattr(e, 'response') and hasattr(e.response, 'headers'):
                        retry_after = e.response.headers.get('retry-after')
                    logger.error("claude_rate_limit", error=str(e), retry_after=retry_after)
                    return None
                elif isinstance(e, anthropic.APIConnectionError):
                    logger.error("claude_connection_error", error=str(e))
                    return None
                elif isinstance(e, anthropic.AuthenticationError):
                    logger.error("claude_auth_error", error=str(e))
                    return None
                elif isinstance(e, anthropic.BadRequestError):
                    status_code = getattr(e, 'status_code', None)
                    logger.error("claude_bad_request", error=str(e), status_code=status_code)
                    return None
                else:
                    logger.error("claude_unknown_error", error=str(e), error_type=type(e).__name__)
                    return None
            except ImportError:
                logger.error("claude_completion_failed", error=str(e))
                return None
    
    async def is_available(self) -> bool:
        """Check if Claude is available."""
        return self.api_key is not None


class LocalProvider(LLMProvider):
    """Local model provider (Ollama, LM Studio, etc.)."""
    
    provider_name = "local"
    
    def __init__(
        self,
        endpoint: str = "http://localhost:11434",
        model: str = "llama2",
        model_path: Optional[str] = None
    ):
        """
        Initialize local provider.
        
        Args:
            endpoint: Local API endpoint
            model: Model name
            model_path: Optional model path (for compatibility)
        """
        self.endpoint = endpoint
        self.model = model
        self.model_path = model_path
    
    async def complete(
        self, messages: List[LLMMessage], max_tokens: int = 500, temperature: float = 0.7
    ) -> Optional[LLMResponse]:
        """Generate completion using local model."""
        try:
            import httpx
            
            start = time.time()
            
            async with httpx.AsyncClient() as client:
                response = await client.post(
                    f"{self.endpoint}/api/chat",
                    json={
                        "model": self.model,
                        "messages": [m.model_dump() for m in messages],
                        "options": {
                            "num_predict": max_tokens,
                            "temperature": temperature,
                        },
                    },
                    timeout=60.0,
                )
                await response.raise_for_status()
                data = await response.json()
            
            latency = (time.time() - start) * 1000
            
            return LLMResponse(
                content=data.get("message", {}).get("content", ""),
                provider=self.provider_name,
                model=self.model,
                tokens_used=0,  # Local doesn't report tokens
                latency_ms=latency,
            )
        except ImportError:
            logger.error("httpx package not installed")
            return None
        except Exception as e:
            logger.error("local_completion_failed", error=str(e))
            return None
    
    async def is_available(self) -> bool:
        """Check if local endpoint is available."""
        try:
            import httpx
            
            async with httpx.AsyncClient() as client:
                response = await client.get(f"{self.endpoint}/api/tags", timeout=2.0)
                return response.status_code == 200
        except:
            return False