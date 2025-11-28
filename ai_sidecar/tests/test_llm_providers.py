"""
Tests for LLM providers (mocked).
"""

import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from ai_sidecar.llm.providers import (
    LLMMessage,
    LLMResponse,
    OpenAIProvider,
    AzureOpenAIProvider,
    DeepSeekProvider,
    ClaudeProvider,
)
from ai_sidecar.llm.manager import LLMManager


@pytest.mark.asyncio
async def test_openai_provider_mock():
    """Test OpenAI provider with mock."""
    provider = OpenAIProvider("test-key", "gpt-4o-mini")
    
    mock_response = MagicMock()
    mock_response.choices = [MagicMock()]
    mock_response.choices[0].message.content = "Test response"
    mock_response.usage.total_tokens = 100
    
    with patch("openai.AsyncOpenAI") as mock_client_class:
        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
        mock_client_class.return_value = mock_client
        
        provider._client = mock_client
        
        messages = [LLMMessage(role="user", content="Test")]
        response = await provider.complete(messages)
        
        assert response is not None
        assert response.content == "Test response"
        assert response.provider == "openai"


@pytest.mark.asyncio
async def test_azure_provider_mock():
    """Test Azure OpenAI provider with mock."""
    provider = AzureOpenAIProvider("test-key", "https://test.openai.azure.com", "gpt-4")
    
    mock_response = MagicMock()
    mock_response.choices = [MagicMock()]
    mock_response.choices[0].message.content = "Azure response"
    mock_response.usage.total_tokens = 150
    
    with patch("openai.AsyncAzureOpenAI") as mock_client_class:
        mock_client = AsyncMock()
        mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
        mock_client_class.return_value = mock_client
        
        provider._client = mock_client
        
        messages = [LLMMessage(role="user", content="Test")]
        response = await provider.complete(messages)
        
        assert response is not None
        assert response.content == "Azure response"


@pytest.mark.asyncio
async def test_deepseek_provider_mock():
    """Test DeepSeek provider with mock."""
    provider = DeepSeekProvider("test-key")
    
    mock_response_data = {
        "choices": [{"message": {"content": "DeepSeek response"}}],
        "usage": {"total_tokens": 120},
    }
    
    with patch("httpx.AsyncClient") as mock_client_class:
        mock_client = AsyncMock()
        mock_response = AsyncMock()
        mock_response.json = AsyncMock(return_value=mock_response_data)
        mock_response.raise_for_status = AsyncMock()
        
        mock_client.post = AsyncMock(return_value=mock_response)
        mock_client.__aenter__ = AsyncMock(return_value=mock_client)
        mock_client.__aexit__ = AsyncMock(return_value=None)
        mock_client_class.return_value = mock_client
        
        messages = [LLMMessage(role="user", content="Test")]
        response = await provider.complete(messages)
        
        assert response is not None
        assert response.content == "DeepSeek response"


@pytest.mark.asyncio
async def test_claude_provider_mock():
    """Test Claude provider with mock."""
    provider = ClaudeProvider("test-key")
    
    mock_response = MagicMock()
    mock_response.content = [MagicMock()]
    mock_response.content[0].text = "Claude response"
    mock_response.usage.input_tokens = 50
    mock_response.usage.output_tokens = 50
    
    with patch("anthropic.AsyncAnthropic") as mock_client_class:
        mock_client = AsyncMock()
        mock_client.messages.create = AsyncMock(return_value=mock_response)
        mock_client_class.return_value = mock_client
        
        provider._client = mock_client
        
        messages = [
            LLMMessage(role="system", content="System prompt"),
            LLMMessage(role="user", content="Test"),
        ]
        response = await provider.complete(messages)
        
        assert response is not None
        assert response.content == "Claude response"
        assert response.tokens_used == 100


@pytest.mark.asyncio
async def test_llm_manager_fallback():
    """Test LLM manager fallback chain."""
    manager = LLMManager()
    
    # Create mock providers
    primary = AsyncMock(spec=OpenAIProvider)
    primary.provider_name = "openai"
    primary.complete = AsyncMock(return_value=None)  # Fails
    
    fallback = AsyncMock(spec=DeepSeekProvider)
    fallback.provider_name = "deepseek"
    fallback.complete = AsyncMock(
        return_value=LLMResponse(
            content="Fallback response",
            provider="deepseek",
            model="deepseek-chat",
        )
    )
    
    manager.add_provider(primary, primary=True)
    manager.add_provider(fallback)
    
    messages = [LLMMessage(role="user", content="Test")]
    response = await manager.complete(messages)
    
    assert response is not None
    assert response.provider == "deepseek"


@pytest.mark.asyncio
async def test_llm_manager_usage_stats():
    """Test LLM manager usage statistics."""
    manager = LLMManager()
    
    provider = AsyncMock(spec=OpenAIProvider)
    provider.provider_name = "openai"
    provider.complete = AsyncMock(
        return_value=LLMResponse(
            content="Test", provider="openai", model="gpt-4o-mini"
        )
    )
    
    manager.add_provider(provider)
    
    # Make multiple requests
    messages = [LLMMessage(role="user", content="Test")]
    for _ in range(3):
        await manager.complete(messages)
    
    stats = manager.get_usage_stats()
    assert stats.get("openai") == 3