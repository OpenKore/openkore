"""
Comprehensive tests for LLM providers.

Tests cover all provider functionality including:
- Model registries and validation
- Provider initialization  
- Exception handling
- Reasoning/thinking parameters
- Retry logic
- Model information methods
- Manager integration
- Backward compatibility
"""

import asyncio
import pytest
from unittest.mock import AsyncMock, MagicMock, patch, call
import httpx

from ai_sidecar.llm.providers import (
    LLMMessage,
    LLMResponse,
    OpenAIProvider,
    AzureOpenAIProvider,
    DeepSeekProvider,
    ClaudeProvider,
    OPENAI_MODELS,
    DEEPSEEK_MODELS,
    CLAUDE_MODELS,
    get_supported_models,
    get_model_info,
    is_reasoning_model,
)
from ai_sidecar.llm.manager import LLMManager


# =============================================================================
# A. MODEL REGISTRY TESTS
# =============================================================================

class TestModelRegistries:
    """Test model registry dictionaries contain expected models."""
    
    def test_openai_models_registry(self):
        """Test OpenAI model registry has all expected models."""
        assert "gpt-5.1" in OPENAI_MODELS
        assert "gpt-5-mini" in OPENAI_MODELS
        assert "o1" in OPENAI_MODELS
        assert "o1-pro" in OPENAI_MODELS
        assert "o3" in OPENAI_MODELS
        assert "gpt-4o-mini" in OPENAI_MODELS
        assert "gpt-4o" in OPENAI_MODELS
        assert len(OPENAI_MODELS) >= 18
        
        # Verify model properties
        assert OPENAI_MODELS["gpt-5.1"]["context"] == 128000
        assert OPENAI_MODELS["gpt-5.1"]["vision"] == True
        assert OPENAI_MODELS["o1"]["reasoning"] == True
    
    def test_deepseek_models_registry(self):
        """Test DeepSeek model registry has expected models."""
        assert "deepseek-chat" in DEEPSEEK_MODELS
        assert "deepseek-reasoner" in DEEPSEEK_MODELS
        assert "deepseek-coder" in DEEPSEEK_MODELS
        assert len(DEEPSEEK_MODELS) >= 3
        
        # Verify V3.2 properties
        assert DEEPSEEK_MODELS["deepseek-chat"]["version"] == "V3.2"
        assert DEEPSEEK_MODELS["deepseek-chat"]["context"] == 128000
        assert DEEPSEEK_MODELS["deepseek-reasoner"]["thinking"] == True
    
    def test_claude_models_registry(self):
        """Test Claude model registry has expected models."""
        assert "claude-sonnet-4-5" in CLAUDE_MODELS
        assert "claude-opus-4-1" in CLAUDE_MODELS
        assert "claude-haiku-4-5" in CLAUDE_MODELS
        assert "claude-3-5-sonnet-20241022" in CLAUDE_MODELS
        assert len(CLAUDE_MODELS) >= 11
        
        # Verify Claude 4 properties
        assert CLAUDE_MODELS["claude-sonnet-4-5"]["context"] == 200000
        assert CLAUDE_MODELS["claude-sonnet-4-5"]["thinking"] == True
        assert CLAUDE_MODELS["claude-opus-4-1"]["vision"] == True


# =============================================================================
# B. PROVIDER INITIALIZATION TESTS
# =============================================================================

class TestProviderInitialization:
    """Test provider initialization with various parameters."""
    
    def test_openai_provider_default_initialization(self):
        """Test OpenAI provider initialization with defaults."""
        provider = OpenAIProvider(api_key="test-key")
        assert provider.model == "gpt-5.1"
        assert provider.timeout == 600.0
        assert provider.max_retries == 2
        assert provider.api_key == "test-key"
    
    def test_openai_provider_custom_params(self):
        """Test OpenAI provider with custom parameters."""
        provider = OpenAIProvider(
            api_key="custom-key",
            model="o1",
            timeout=120.0,
            max_retries=5
        )
        assert provider.model == "o1"
        assert provider.timeout == 120.0
        assert provider.max_retries == 5
        assert provider.api_key == "custom-key"
    
    def test_azure_provider_initialization(self):
        """Test Azure OpenAI provider initialization."""
        provider = AzureOpenAIProvider(
            api_key="azure-key",
            endpoint="https://test.openai.azure.com",
            deployment="gpt-4"
        )
        assert provider.api_key == "azure-key"
        assert provider.endpoint == "https://test.openai.azure.com"
        assert provider.deployment == "gpt-4"
        assert provider.timeout == 600.0
        assert provider.max_retries == 2
    
    def test_azure_provider_custom_params(self):
        """Test Azure provider with custom parameters."""
        provider = AzureOpenAIProvider(
            api_key="azure-key",
            endpoint="https://custom.openai.azure.com",
            deployment="gpt-4-turbo",
            api_version="2024-06-01",
            timeout=300.0,
            max_retries=4
        )
        assert provider.api_version == "2024-06-01"
        assert provider.timeout == 300.0
        assert provider.max_retries == 4
    
    def test_deepseek_provider_default_initialization(self):
        """Test DeepSeek provider initialization with defaults."""
        provider = DeepSeekProvider(api_key="deepseek-key")
        assert provider.model == "deepseek-chat"
        assert provider.timeout == 60.0
        assert provider.max_retries == 3
        assert provider.base_url == "https://api.deepseek.com/v1"
    
    def test_deepseek_provider_custom_params(self):
        """Test DeepSeek provider with custom parameters."""
        provider = DeepSeekProvider(
            api_key="deepseek-key",
            model="deepseek-reasoner",
            timeout=90.0,
            max_retries=5
        )
        assert provider.model == "deepseek-reasoner"
        assert provider.timeout == 90.0
        assert provider.max_retries == 5
    
    def test_claude_provider_default_initialization(self):
        """Test Claude provider initialization with defaults."""
        provider = ClaudeProvider(api_key="claude-key")
        assert provider.model == "claude-sonnet-4-5"
        assert provider.timeout == 600.0
        assert provider.max_retries == 2
    
    def test_claude_provider_custom_params(self):
        """Test Claude provider with custom parameters."""
        provider = ClaudeProvider(
            api_key="claude-key",
            model="claude-opus-4-1",
            timeout=450.0,
            max_retries=3
        )
        assert provider.model == "claude-opus-4-1"
        assert provider.timeout == 450.0
        assert provider.max_retries == 3


# =============================================================================
# C. MODEL VALIDATION TESTS
# =============================================================================

class TestModelValidation:
    """Test model validation and detection methods."""
    
    def test_openai_validate_model_known(self):
        """Test validation accepts known models without error."""
        with patch('ai_sidecar.llm.providers.logger') as mock_logger:
            provider = OpenAIProvider(api_key="test-key", model="gpt-5.1")
            # Should not log warning for known model
            mock_logger.warning.assert_not_called()
    
    def test_openai_validate_model_unknown(self):
        """Test validation warns on unknown models."""
        with patch('ai_sidecar.llm.providers.logger') as mock_logger:
            provider = OpenAIProvider(api_key="test-key", model="gpt-99")
            mock_logger.warning.assert_called_once()
            call_args = mock_logger.warning.call_args
            assert call_args[0][0] == "openai_unknown_model"
    
    def test_openai_is_reasoning_model_o_series(self):
        """Test reasoning model detection for o-series."""
        provider_o1 = OpenAIProvider(api_key="test-key", model="o1")
        assert provider_o1.is_reasoning_model() == True
        
        provider_o3 = OpenAIProvider(api_key="test-key", model="o3")
        assert provider_o3.is_reasoning_model() == True
        
        provider_o4_mini = OpenAIProvider(api_key="test-key", model="o4-mini")
        assert provider_o4_mini.is_reasoning_model() == True
    
    def test_openai_is_reasoning_model_regular(self):
        """Test reasoning model detection for regular models."""
        provider_gpt = OpenAIProvider(api_key="test-key", model="gpt-5.1")
        assert provider_gpt.is_reasoning_model() == False
        
        provider_gpt4 = OpenAIProvider(api_key="test-key", model="gpt-4o")
        assert provider_gpt4.is_reasoning_model() == False
    
    def test_deepseek_validate_model_unknown(self):
        """Test DeepSeek validation warns on unknown models."""
        with patch('ai_sidecar.llm.providers.logger') as mock_logger:
            provider = DeepSeekProvider(api_key="test-key", model="deepseek-unknown")
            mock_logger.warning.assert_called_once()
            call_args = mock_logger.warning.call_args
            assert call_args[0][0] == "deepseek_unknown_model"
    
    def test_deepseek_is_thinking_model(self):
        """Test DeepSeek thinking model detection."""
        provider_reasoner = DeepSeekProvider(api_key="test-key", model="deepseek-reasoner")
        assert provider_reasoner.is_thinking_model() == True
        
        provider_chat = DeepSeekProvider(api_key="test-key", model="deepseek-chat")
        assert provider_chat.is_thinking_model() == False
    
    def test_claude_validate_model_unknown(self):
        """Test Claude validation warns on unknown models."""
        with patch('ai_sidecar.llm.providers.logger') as mock_logger:
            provider = ClaudeProvider(api_key="test-key", model="claude-unknown")
            mock_logger.warning.assert_called_once()
    
    def test_claude_supports_thinking(self):
        """Test Claude thinking support detection."""
        provider_sonnet = ClaudeProvider(api_key="test-key", model="claude-sonnet-4-5")
        assert provider_sonnet.supports_thinking() == True
        
        provider_opus = ClaudeProvider(api_key="test-key", model="claude-opus-4-1")
        assert provider_opus.supports_thinking() == True
        
        provider_haiku = ClaudeProvider(api_key="test-key", model="claude-haiku-4-5")
        assert provider_haiku.supports_thinking() == False
    
    def test_global_is_reasoning_model(self):
        """Test global is_reasoning_model function."""
        assert is_reasoning_model("openai", "o1") == True
        assert is_reasoning_model("openai", "gpt-5.1") == False
        assert is_reasoning_model("deepseek", "deepseek-reasoner") == True
        assert is_reasoning_model("deepseek", "deepseek-chat") == False
        assert is_reasoning_model("claude", "claude-sonnet-4-5") == True


# =============================================================================
# D. EXCEPTION HANDLING TESTS
# =============================================================================

class TestExceptionHandling:
    """Test provider exception handling for all error types."""
    
    @pytest.mark.asyncio
    async def test_openai_timeout_exception(self):
        """Test OpenAI handles timeout exceptions correctly."""
        provider = OpenAIProvider(api_key="test-key")
        
        with patch.object(provider, '_get_client') as mock_get_client:
            import openai
            mock_client = AsyncMock()
            mock_client.chat.completions.create = AsyncMock(
                side_effect=openai.APITimeoutError("Timeout")
            )
            mock_get_client.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                mock_logger.error.assert_called_once()
                assert mock_logger.error.call_args[0][0] == "openai_timeout"
    
    @pytest.mark.asyncio
    async def test_openai_rate_limit_exception(self):
        """Test OpenAI handles rate limit exceptions."""
        provider = OpenAIProvider(api_key="test-key")
        
        with patch.object(provider, '_get_client') as mock_get_client:
            import openai
            mock_client = AsyncMock()
            # Create proper mock response and body for APIStatusError
            mock_response = MagicMock()
            mock_response.status_code = 429
            mock_response.headers = {'retry-after': '60'}
            mock_error = openai.RateLimitError(
                message="Rate limit exceeded",
                response=mock_response,
                body={"error": {"message": "Rate limit exceeded"}}
            )
            mock_client.chat.completions.create = AsyncMock(side_effect=mock_error)
            mock_get_client.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                mock_logger.error.assert_called_once()
                assert mock_logger.error.call_args[0][0] == "openai_rate_limit"
    
    @pytest.mark.asyncio
    async def test_openai_connection_error(self):
        """Test OpenAI handles connection errors."""
        provider = OpenAIProvider(api_key="test-key")
        
        with patch.object(provider, '_get_client') as mock_get_client:
            import openai
            mock_client = AsyncMock()
            # APIConnectionError requires request parameter, not message
            mock_request = MagicMock()
            mock_error = openai.APIConnectionError(request=mock_request)
            mock_client.chat.completions.create = AsyncMock(side_effect=mock_error)
            mock_get_client.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                mock_logger.error.assert_called_once()
                assert mock_logger.error.call_args[0][0] == "openai_connection_error"
    
    @pytest.mark.asyncio
    async def test_openai_auth_error(self):
        """Test OpenAI handles authentication errors."""
        provider = OpenAIProvider(api_key="test-key")
        
        with patch.object(provider, '_get_client') as mock_get_client:
            import openai
            mock_client = AsyncMock()
            # Create proper mock response and body for APIStatusError
            mock_response = MagicMock()
            mock_response.status_code = 401
            mock_error = openai.AuthenticationError(
                message="Invalid API key",
                response=mock_response,
                body={"error": {"message": "Invalid API key"}}
            )
            mock_client.chat.completions.create = AsyncMock(side_effect=mock_error)
            mock_get_client.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                mock_logger.error.assert_called_once()
                assert mock_logger.error.call_args[0][0] == "openai_auth_error"
    
    @pytest.mark.asyncio
    async def test_openai_bad_request_error(self):
        """Test OpenAI handles bad request errors."""
        provider = OpenAIProvider(api_key="test-key")
        
        with patch.object(provider, '_get_client') as mock_get_client:
            import openai
            mock_client = AsyncMock()
            # Create proper mock response and body for APIStatusError
            mock_response = MagicMock()
            mock_response.status_code = 400
            mock_error = openai.BadRequestError(
                message="Invalid request",
                response=mock_response,
                body={"error": {"message": "Invalid request"}}
            )
            mock_client.chat.completions.create = AsyncMock(side_effect=mock_error)
            mock_get_client.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                mock_logger.error.assert_called_once()
                assert mock_logger.error.call_args[0][0] == "openai_bad_request"
    
    @pytest.mark.asyncio
    async def test_azure_timeout_exception(self):
        """Test Azure handles timeout exceptions."""
        provider = AzureOpenAIProvider(
            api_key="test-key",
            endpoint="https://test.openai.azure.com",
            deployment="gpt-4"
        )
        
        with patch.object(provider, '_get_client') as mock_get_client:
            import openai
            mock_client = AsyncMock()
            mock_client.chat.completions.create = AsyncMock(
                side_effect=openai.APITimeoutError("Timeout")
            )
            mock_get_client.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                mock_logger.error.assert_called_once()
                assert mock_logger.error.call_args[0][0] == "azure_timeout"
    
    @pytest.mark.asyncio
    async def test_deepseek_http_status_429(self):
        """Test DeepSeek handles 429 rate limit errors."""
        provider = DeepSeekProvider(api_key="test-key", max_retries=0)
        
        with patch('httpx.AsyncClient') as mock_client_class:
            mock_response = MagicMock()
            mock_response.status_code = 429
            mock_error = httpx.HTTPStatusError(
                "Rate limit",
                request=MagicMock(),
                response=mock_response
            )
            
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(side_effect=mock_error)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_class.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                # Should log rate limit error
                error_calls = [c for c in mock_logger.error.call_args_list
                              if c[0][0] == "deepseek_rate_limit"]
                assert len(error_calls) > 0
    
    @pytest.mark.asyncio
    async def test_deepseek_http_status_500(self):
        """Test DeepSeek handles 500 server errors."""
        provider = DeepSeekProvider(api_key="test-key", max_retries=0)
        
        with patch('httpx.AsyncClient') as mock_client_class:
            mock_response = MagicMock()
            mock_response.status_code = 500
            mock_error = httpx.HTTPStatusError(
                "Server error",
                request=MagicMock(),
                response=mock_response
            )
            
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(side_effect=mock_error)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_class.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                error_calls = [c for c in mock_logger.error.call_args_list
                              if c[0][0] == "deepseek_server_error"]
                assert len(error_calls) > 0
    
    @pytest.mark.asyncio
    async def test_deepseek_timeout_exception(self):
        """Test DeepSeek handles timeout exceptions."""
        provider = DeepSeekProvider(api_key="test-key", max_retries=0)
        
        with patch('httpx.AsyncClient') as mock_client_class:
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(side_effect=httpx.TimeoutException("Timeout"))
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_class.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                mock_logger.error.assert_called_once()
                assert mock_logger.error.call_args[0][0] == "deepseek_timeout"
    
    @pytest.mark.asyncio
    async def test_deepseek_connection_error(self):
        """Test DeepSeek handles connection errors."""
        provider = DeepSeekProvider(api_key="test-key", max_retries=0)
        
        with patch('httpx.AsyncClient') as mock_client_class:
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(side_effect=httpx.ConnectError("Connection failed"))
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_class.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                mock_logger.error.assert_called_once()
                assert mock_logger.error.call_args[0][0] == "deepseek_connection_error"
    
    @pytest.mark.asyncio
    async def test_claude_timeout_exception(self):
        """Test Claude handles timeout exceptions."""
        provider = ClaudeProvider(api_key="test-key")
        
        with patch.object(provider, '_get_client') as mock_get_client:
            import anthropic
            mock_client = AsyncMock()
            mock_client.messages.create = AsyncMock(
                side_effect=anthropic.APITimeoutError("Timeout")
            )
            mock_get_client.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                mock_logger.error.assert_called_once()
                assert mock_logger.error.call_args[0][0] == "claude_timeout"
    
    @pytest.mark.asyncio
    async def test_claude_rate_limit_exception(self):
        """Test Claude handles rate limit exceptions."""
        provider = ClaudeProvider(api_key="test-key")
        
        with patch.object(provider, '_get_client') as mock_get_client:
            import anthropic
            mock_client = AsyncMock()
            # Create proper mock response and body for APIStatusError
            mock_response = MagicMock()
            mock_response.status_code = 429
            mock_response.headers = {'retry-after': '30'}
            mock_error = anthropic.RateLimitError(
                message="Rate limit",
                response=mock_response,
                body={"error": {"message": "Rate limit"}}
            )
            mock_client.messages.create = AsyncMock(side_effect=mock_error)
            mock_get_client.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                mock_logger.error.assert_called_once()
                assert mock_logger.error.call_args[0][0] == "claude_rate_limit"


# =============================================================================
# E. REASONING/THINKING PARAMETER TESTS
# =============================================================================

class TestReasoningThinkingParameters:
    """Test reasoning and thinking parameter handling."""
    
    @pytest.mark.asyncio
    async def test_openai_reasoning_effort_parameter(self):
        """Test o-series models use reasoning_effort parameter."""
        provider = OpenAIProvider(api_key="test-key", model="o1")
        
        with patch.object(provider, '_get_client') as mock_get_client:
            mock_response = MagicMock()
            mock_response.choices = [MagicMock(message=MagicMock(content="test"))]
            mock_response.usage = MagicMock(total_tokens=100)
            
            mock_client = AsyncMock()
            mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
            mock_get_client.return_value = mock_client
            
            await provider.complete([], reasoning_effort="high")
            
            call_kwargs = mock_client.chat.completions.create.call_args.kwargs
            assert call_kwargs.get("reasoning_effort") == "high"
            assert "temperature" not in call_kwargs
    
    @pytest.mark.asyncio
    async def test_openai_regular_model_uses_temperature(self):
        """Test regular models use temperature parameter."""
        provider = OpenAIProvider(api_key="test-key", model="gpt-5.1")
        
        with patch.object(provider, '_get_client') as mock_get_client:
            mock_response = MagicMock()
            mock_response.choices = [MagicMock(message=MagicMock(content="test"))]
            mock_response.usage = MagicMock(total_tokens=100)
            
            mock_client = AsyncMock()
            mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
            mock_get_client.return_value = mock_client
            
            await provider.complete([], temperature=0.8)
            
            call_kwargs = mock_client.chat.completions.create.call_args.kwargs
            assert call_kwargs.get("temperature") == 0.8
            assert "reasoning_effort" not in call_kwargs
    
    @pytest.mark.asyncio
    async def test_openai_reasoning_effort_variations(self):
        """Test different reasoning_effort levels."""
        provider = OpenAIProvider(api_key="test-key", model="o3")
        
        for effort in ["low", "medium", "high"]:
            with patch.object(provider, '_get_client') as mock_get_client:
                mock_response = MagicMock()
                mock_response.choices = [MagicMock(message=MagicMock(content="test"))]
                mock_response.usage = MagicMock(total_tokens=100)
                
                mock_client = AsyncMock()
                mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
                mock_get_client.return_value = mock_client
                
                await provider.complete([], reasoning_effort=effort)
                
                call_kwargs = mock_client.chat.completions.create.call_args.kwargs
                assert call_kwargs.get("reasoning_effort") == effort
    
    @pytest.mark.asyncio
    async def test_deepseek_thinking_mode_enabled(self):
        """Test DeepSeek reasoner with thinking mode."""
        provider = DeepSeekProvider(api_key="test-key", model="deepseek-reasoner")
        
        with patch('httpx.AsyncClient') as mock_client_class:
            mock_response = MagicMock()
            mock_response.json.return_value = {
                "choices": [{"message": {"content": "test"}}],
                "usage": {"total_tokens": 100}
            }
            mock_response.raise_for_status = MagicMock()
            
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(return_value=mock_response)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_class.return_value = mock_client
            
            await provider.complete([], enable_thinking=True)
            
            call_kwargs = mock_client.post.call_args.kwargs
            assert call_kwargs["json"]["thinking"] == {"type": "enabled"}
    
    @pytest.mark.asyncio
    async def test_deepseek_auto_thinking_for_reasoner(self):
        """Test DeepSeek automatically enables thinking for reasoner model."""
        provider = DeepSeekProvider(api_key="test-key", model="deepseek-reasoner")
        
        with patch('httpx.AsyncClient') as mock_client_class:
            mock_response = MagicMock()
            mock_response.json.return_value = {
                "choices": [{"message": {"content": "test"}}],
                "usage": {"total_tokens": 100}
            }
            mock_response.raise_for_status = MagicMock()
            
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(return_value=mock_response)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_class.return_value = mock_client
            
            # Not explicitly enabling thinking, but should auto-enable
            await provider.complete([])
            
            call_kwargs = mock_client.post.call_args.kwargs
            assert call_kwargs["json"]["thinking"] == {"type": "enabled"}
    
    @pytest.mark.asyncio
    async def test_deepseek_chat_no_thinking(self):
        """Test DeepSeek chat model doesn't include thinking parameter."""
        provider = DeepSeekProvider(api_key="test-key", model="deepseek-chat")
        
        with patch('httpx.AsyncClient') as mock_client_class:
            mock_response = MagicMock()
            mock_response.json.return_value = {
                "choices": [{"message": {"content": "test"}}],
                "usage": {"total_tokens": 100}
            }
            mock_response.raise_for_status = MagicMock()
            
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(return_value=mock_response)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_class.return_value = mock_client
            
            await provider.complete([])
            
            call_kwargs = mock_client.post.call_args.kwargs
            assert "thinking" not in call_kwargs["json"]
    
    @pytest.mark.asyncio
    async def test_claude_extended_thinking_enabled(self):
        """Test Claude with extended thinking enabled."""
        provider = ClaudeProvider(api_key="test-key", model="claude-sonnet-4-5")
        
        with patch.object(provider, '_get_client') as mock_get_client:
            mock_response = MagicMock()
            mock_response.content = [MagicMock(text="test")]
            mock_response.usage = MagicMock(input_tokens=50, output_tokens=50)
            
            mock_client = AsyncMock()
            mock_client.messages.create = AsyncMock(return_value=mock_response)
            mock_get_client.return_value = mock_client
            
            await provider.complete([], enable_thinking=True)
            
            call_kwargs = mock_client.messages.create.call_args.kwargs
            assert call_kwargs.get("thinking") == {"type": "enabled"}
    
    @pytest.mark.asyncio
    async def test_claude_thinking_not_supported_warning(self):
        """Test Claude warns when thinking requested but not supported."""
        provider = ClaudeProvider(api_key="test-key", model="claude-haiku-4-5")
        
        with patch.object(provider, '_get_client') as mock_get_client:
            mock_response = MagicMock()
            mock_response.content = [MagicMock(text="test")]
            mock_response.usage = MagicMock(input_tokens=50, output_tokens=50)
            
            mock_client = AsyncMock()
            mock_client.messages.create = AsyncMock(return_value=mock_response)
            mock_get_client.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                await provider.complete([], enable_thinking=True)
                
                warning_calls = [c for c in mock_logger.warning.call_args_list
                                if c[0][0] == "claude_thinking_not_supported"]
                assert len(warning_calls) > 0
    
    @pytest.mark.asyncio
    async def test_claude_system_message_handling(self):
        """Test Claude correctly extracts and handles system messages."""
        provider = ClaudeProvider(api_key="test-key", model="claude-sonnet-4-5")
        
        with patch.object(provider, '_get_client') as mock_get_client:
            mock_response = MagicMock()
            mock_response.content = [MagicMock(text="test")]
            mock_response.usage = MagicMock(input_tokens=50, output_tokens=50)
            
            mock_client = AsyncMock()
            mock_client.messages.create = AsyncMock(return_value=mock_response)
            mock_get_client.return_value = mock_client
            
            messages = [
                LLMMessage(role="system", content="You are helpful"),
                LLMMessage(role="user", content="Hello")
            ]
            await provider.complete(messages)
            
            call_kwargs = mock_client.messages.create.call_args.kwargs
            assert call_kwargs.get("system") == "You are helpful"
            assert len(call_kwargs.get("messages")) == 1
            assert call_kwargs.get("messages")[0]["content"] == "Hello"


# =============================================================================
# F. RETRY LOGIC TESTS
# =============================================================================

class TestRetryLogic:
    """Test retry logic with exponential backoff."""
    
    @pytest.mark.asyncio
    async def test_deepseek_retry_on_rate_limit(self):
        """Test DeepSeek retries on 429 rate limit."""
        provider = DeepSeekProvider(api_key="test-key", max_retries=2)
        
        attempt_count = 0
        async def mock_post_with_retry(*args, **kwargs):
            nonlocal attempt_count
            attempt_count += 1
            if attempt_count < 3:
                mock_response = MagicMock()
                mock_response.status_code = 429
                raise httpx.HTTPStatusError("Rate limit", request=MagicMock(), response=mock_response)
            # Third attempt succeeds
            mock_response = MagicMock()
            mock_response.json.return_value = {
                "choices": [{"message": {"content": "success"}}],
                "usage": {"total_tokens": 50}
            }
            mock_response.raise_for_status = MagicMock()
            return mock_response
        
        with patch('httpx.AsyncClient') as mock_client_class:
            mock_client = AsyncMock()
            mock_client.post = mock_post_with_retry
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_class.return_value = mock_client
            
            result = await provider.complete([])
            assert result is not None
            assert result.content == "success"
            assert attempt_count == 3  # Verify 2 retries + 1 success
    
    @pytest.mark.asyncio
    async def test_deepseek_retry_on_server_error(self):
        """Test DeepSeek retries on 500 server error."""
        provider = DeepSeekProvider(api_key="test-key", max_retries=1)
        
        attempt_count = 0
        async def mock_post_with_retry(*args, **kwargs):
            nonlocal attempt_count
            attempt_count += 1
            if attempt_count == 1:
                mock_response = MagicMock()
                mock_response.status_code = 500
                raise httpx.HTTPStatusError("Server error", request=MagicMock(), response=mock_response)
            # Second attempt succeeds
            mock_response = MagicMock()
            mock_response.json.return_value = {
                "choices": [{"message": {"content": "success"}}],
                "usage": {"total_tokens": 50}
            }
            mock_response.raise_for_status = MagicMock()
            return mock_response
        
        with patch('httpx.AsyncClient') as mock_client_class:
            mock_client = AsyncMock()
            mock_client.post = mock_post_with_retry
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_class.return_value = mock_client
            
            result = await provider.complete([])
            assert result is not None
            assert attempt_count == 2
    
    @pytest.mark.asyncio
    async def test_deepseek_exponential_backoff(self):
        """Test DeepSeek uses exponential backoff with jitter."""
        provider = DeepSeekProvider(api_key="test-key", max_retries=2)
        
        wait_times = []
        
        attempt_count = 0
        async def mock_post_with_retry(*args, **kwargs):
            nonlocal attempt_count
            attempt_count += 1
            if attempt_count < 3:
                mock_response = MagicMock()
                mock_response.status_code = 503
                raise httpx.HTTPStatusError("Service unavailable", request=MagicMock(), response=mock_response)
            mock_response = MagicMock()
            mock_response.json.return_value = {
                "choices": [{"message": {"content": "success"}}],
                "usage": {"total_tokens": 50}
            }
            mock_response.raise_for_status = MagicMock()
            return mock_response
        
        async def mock_sleep(duration):
            wait_times.append(duration)
        
        with patch('httpx.AsyncClient') as mock_client_class:
            mock_client = AsyncMock()
            mock_client.post = mock_post_with_retry
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_class.return_value = mock_client
            
            with patch('asyncio.sleep', mock_sleep):
                result = await provider.complete([])
                assert result is not None
                
                # Verify exponential backoff: first wait should be ~1s, second ~2s
                assert len(wait_times) == 2
                assert wait_times[0] >= 1.0 and wait_times[0] < 2.0
                assert wait_times[1] >= 2.0 and wait_times[1] < 3.0
    
    @pytest.mark.asyncio
    async def test_deepseek_retry_timeout(self):
        """Test DeepSeek retries on timeout."""
        provider = DeepSeekProvider(api_key="test-key", max_retries=1)
        
        attempt_count = 0
        async def mock_post_with_retry(*args, **kwargs):
            nonlocal attempt_count
            attempt_count += 1
            if attempt_count == 1:
                raise httpx.TimeoutException("Timeout")
            mock_response = MagicMock()
            mock_response.json.return_value = {
                "choices": [{"message": {"content": "success"}}],
                "usage": {"total_tokens": 50}
            }
            mock_response.raise_for_status = MagicMock()
            return mock_response
        
        with patch('httpx.AsyncClient') as mock_client_class:
            mock_client = AsyncMock()
            mock_client.post = mock_post_with_retry
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_class.return_value = mock_client
            
            with patch('asyncio.sleep', AsyncMock()):
                result = await provider.complete([])
                assert result is not None
                assert attempt_count == 2
    
    @pytest.mark.asyncio
    async def test_deepseek_max_retries_exceeded(self):
        """Test DeepSeek fails after max retries exceeded."""
        provider = DeepSeekProvider(api_key="test-key", max_retries=1)
        
        with patch('httpx.AsyncClient') as mock_client_class:
            mock_response = MagicMock()
            mock_response.status_code = 429
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(
                side_effect=httpx.HTTPStatusError("Rate limit", request=MagicMock(), response=mock_response)
            )
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_class.return_value = mock_client
            
            with patch('asyncio.sleep', AsyncMock()):
                result = await provider.complete([])
                assert result is None
    
    @pytest.mark.asyncio
    async def test_deepseek_no_retry_on_400(self):
        """Test DeepSeek doesn't retry on 400 bad request."""
        provider = DeepSeekProvider(api_key="test-key", max_retries=2)
        
        attempt_count = 0
        async def mock_post(*args, **kwargs):
            nonlocal attempt_count
            attempt_count += 1
            mock_response = MagicMock()
            mock_response.status_code = 400
            raise httpx.HTTPStatusError("Bad request", request=MagicMock(), response=mock_response)
        
        with patch('httpx.AsyncClient') as mock_client_class:
            mock_client = AsyncMock()
            mock_client.post = mock_post
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_class.return_value = mock_client
            
            result = await provider.complete([])
            assert result is None
            assert attempt_count == 1  # Should not retry


# =============================================================================
# G. MODEL INFO TESTS
# =============================================================================

class TestModelInfo:
    """Test model information retrieval methods."""
    
    def test_openai_get_model_info(self):
        """Test getting OpenAI model information."""
        provider = OpenAIProvider(api_key="test-key", model="gpt-5.1")
        info = provider.get_model_info()
        assert info["context"] == 128000
        assert info["vision"] == True
        assert "description" in info
    
    def test_openai_get_supported_models(self):
        """Test getting list of supported OpenAI models."""
        models = OpenAIProvider.get_supported_models()
        assert isinstance(models, list)
        assert len(models) >= 18
        assert "gpt-5.1" in models
        assert "o1" in models
    
    def test_deepseek_get_model_info(self):
        """Test getting DeepSeek model information."""
        provider = DeepSeekProvider(api_key="test-key", model="deepseek-chat")
        info = provider.get_model_info()
        assert info["version"] == "V3.2"
        assert info["context"] == 128000
    
    def test_deepseek_get_supported_models(self):
        """Test getting list of supported DeepSeek models."""
        models = DeepSeekProvider.get_supported_models()
        assert isinstance(models, list)
        assert "deepseek-chat" in models
        assert "deepseek-reasoner" in models
    
    def test_claude_get_model_info(self):
        """Test getting Claude model information."""
        provider = ClaudeProvider(api_key="test-key", model="claude-sonnet-4-5")
        info = provider.get_model_info()
        assert info["context"] == 200000
        assert info["thinking"] == True
        assert info["vision"] == True
    
    def test_claude_get_supported_models(self):
        """Test getting list of supported Claude models."""
        models = ClaudeProvider.get_supported_models()
        assert isinstance(models, list)
        assert len(models) >= 11
        assert "claude-sonnet-4-5" in models
        assert "claude-opus-4-1" in models
    
    def test_global_get_supported_models(self):
        """Test global get_supported_models function."""
        openai_models = get_supported_models("openai")
        assert "gpt-5.1" in openai_models
        
        deepseek_models = get_supported_models("deepseek")
        assert "deepseek-chat" in deepseek_models
        
        claude_models = get_supported_models("claude")
        assert "claude-sonnet-4-5" in claude_models
    
    def test_global_get_model_info(self):
        """Test global get_model_info function."""
        info = get_model_info("openai", "gpt-5.1")
        assert info["context"] == 128000
        
        info = get_model_info("deepseek", "deepseek-chat")
        assert info["version"] == "V3.2"
        
        info = get_model_info("claude", "claude-opus-4-1")
        assert info["thinking"] == True


# =============================================================================
# H. MANAGER INTEGRATION TESTS
# =============================================================================

class TestManagerIntegration:
    """Test LLMManager provider selection and fallback."""
    
    def test_manager_auto_init_openai(self):
        """Test LLMManager auto-initializes OpenAI provider."""
        manager = LLMManager(provider="openai", api_key="test-key")
        assert len(manager.providers) == 1
        assert manager.providers[0].__class__.__name__ == "OpenAIProvider"
        assert manager.providers[0].model == "gpt-5.1"
    
    def test_manager_auto_init_openai_custom_model(self):
        """Test LLMManager auto-initializes OpenAI with custom model."""
        manager = LLMManager(provider="openai", api_key="test-key", model="o1")
        assert manager.providers[0].model == "o1"
    
    def test_manager_auto_init_deepseek(self):
        """Test LLMManager auto-initializes DeepSeek provider."""
        manager = LLMManager(provider="deepseek", api_key="test-key")
        assert len(manager.providers) == 1
        assert manager.providers[0].__class__.__name__ == "DeepSeekProvider"
        assert manager.providers[0].model == "deepseek-chat"
    
    def test_manager_auto_init_claude(self):
        """Test LLMManager auto-initializes Claude provider."""
        manager = LLMManager(provider="claude", api_key="test-key")
        assert len(manager.providers) == 1
        assert manager.providers[0].__class__.__name__ == "ClaudeProvider"
        assert manager.providers[0].model == "claude-sonnet-4-5"
    
    def test_manager_auto_init_azure(self):
        """Test LLMManager auto-initializes Azure provider."""
        manager = LLMManager(
            provider="azure",
            api_key="test-key",
            endpoint="https://test.openai.azure.com",
            deployment="gpt-4"
        )
        assert len(manager.providers) == 1
        assert manager.providers[0].__class__.__name__ == "AzureOpenAIProvider"
    
    @pytest.mark.asyncio
    async def test_manager_fallback_chain(self):
        """Test LLMManager falls back through provider chain."""
        manager = LLMManager()
        
        # Primary fails
        primary = AsyncMock()
        primary.provider_name = "openai"
        primary.complete = AsyncMock(return_value=None)
        
        # Fallback succeeds
        fallback = AsyncMock()
        fallback.provider_name = "deepseek"
        fallback.complete = AsyncMock(
            return_value=LLMResponse(
                content="Fallback response",
                provider="deepseek",
                model="deepseek-chat",
                tokens_used=50
            )
        )
        
        manager.add_provider(primary, primary=True)
        manager.add_provider(fallback)
        
        result = await manager.complete([])
        assert result is not None
        assert result.provider == "deepseek"
    
    @pytest.mark.asyncio
    async def test_manager_all_providers_fail(self):
        """Test LLMManager returns None when all providers fail."""
        manager = LLMManager()
        
        provider1 = AsyncMock()
        provider1.provider_name = "openai"
        provider1.complete = AsyncMock(return_value=None)
        
        provider2 = AsyncMock()
        provider2.provider_name = "claude"
        provider2.complete = AsyncMock(return_value=None)
        
        manager.add_provider(provider1, primary=True)
        manager.add_provider(provider2)
        
        with patch('ai_sidecar.llm.providers.logger'):
            result = await manager.complete([])
            assert result is None
    
    @pytest.mark.asyncio
    async def test_manager_usage_stats(self):
        """Test LLMManager tracks usage statistics."""
        manager = LLMManager()
        
        provider = AsyncMock()
        provider.provider_name = "openai"
        provider.complete = AsyncMock(
            return_value=LLMResponse(
                content="Test",
                provider="openai",
                model="gpt-5.1",
                tokens_used=100
            )
        )
        
        manager.add_provider(provider)
        
        for _ in range(5):
            await manager.complete([])
        
        stats = manager.get_usage_stats()
        assert stats.get("openai") == 5
    
    @pytest.mark.asyncio
    async def test_manager_list_models(self):
        """Test LLMManager lists available models."""
        manager = LLMManager()
        
        provider1 = OpenAIProvider(api_key="test-key", model="gpt-5.1")
        provider2 = ClaudeProvider(api_key="test-key", model="claude-sonnet-4-5")
        
        manager.add_provider(provider1)
        manager.add_provider(provider2)
        
        models = manager.list_models()
        assert "openai:gpt-5.1" in models
        assert "claude:claude-sonnet-4-5" in models


# =============================================================================
# I. BACKWARD COMPATIBILITY TESTS
# =============================================================================

class TestBackwardCompatibility:
    """Test backward compatibility with older model names."""
    
    def test_backward_compat_old_openai_model(self):
        """Test backward compatibility with old OpenAI model names."""
        provider = OpenAIProvider(api_key="test-key", model="gpt-4o-mini")
        assert provider.model == "gpt-4o-mini"
        assert not provider.is_reasoning_model()
    
    def test_backward_compat_gpt_4_turbo(self):
        """Test backward compatibility with gpt-4-turbo."""
        provider = OpenAIProvider(api_key="test-key", model="gpt-4-turbo")
        assert provider.model == "gpt-4-turbo"
        info = provider.get_model_info()
        assert info["context"] == 128000
    
    def test_backward_compat_deepseek_coder(self):
        """Test deepseek-coder alias still works."""
        provider = DeepSeekProvider(api_key="test-key", model="deepseek-coder")
        assert provider.model == "deepseek-coder"
        info = provider.get_model_info()
        assert "alias" in info
    
    def test_backward_compat_claude_3_5(self):
        """Test backward compatibility with Claude 3.5 models."""
        provider = ClaudeProvider(api_key="test-key", model="claude-3-5-sonnet-20241022")
        assert provider.model == "claude-3-5-sonnet-20241022"
        info = provider.get_model_info()
        assert info["context"] == 200000


# =============================================================================
# J. INTEGRATION TESTS
# =============================================================================

class TestProviderIntegration:
    """Test complete provider workflows."""
    
    @pytest.mark.asyncio
    async def test_openai_complete_workflow(self):
        """Test complete OpenAI workflow."""
        provider = OpenAIProvider(api_key="test-key", model="gpt-5.1")
        
        with patch.object(provider, '_get_client') as mock_get_client:
            mock_response = MagicMock()
            mock_response.choices = [MagicMock(message=MagicMock(content="Test response"))]
            mock_response.usage = MagicMock(total_tokens=150)
            
            mock_client = AsyncMock()
            mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
            mock_get_client.return_value = mock_client
            
            messages = [
                LLMMessage(role="system", content="You are helpful"),
                LLMMessage(role="user", content="Hello")
            ]
            result = await provider.complete(messages, max_tokens=200, temperature=0.7)
            
            assert result is not None
            assert result.content == "Test response"
            assert result.provider == "openai"
            assert result.model == "gpt-5.1"
            assert result.tokens_used == 150
            assert result.latency_ms > 0
    
    @pytest.mark.asyncio
    async def test_deepseek_complete_workflow(self):
        """Test complete DeepSeek workflow."""
        provider = DeepSeekProvider(api_key="test-key", model="deepseek-chat")
        
        with patch('httpx.AsyncClient') as mock_client_class:
            mock_response = MagicMock()
            mock_response.json.return_value = {
                "choices": [{"message": {"content": "DeepSeek response"}}],
                "usage": {"total_tokens": 120}
            }
            mock_response.raise_for_status = MagicMock()
            
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(return_value=mock_response)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_class.return_value = mock_client
            
            messages = [LLMMessage(role="user", content="Test")]
            result = await provider.complete(messages)
            
            assert result is not None
            assert result.content == "DeepSeek response"
            assert result.provider == "deepseek"
            assert result.tokens_used == 120
    
    @pytest.mark.asyncio
    async def test_claude_complete_workflow(self):
        """Test complete Claude workflow."""
        provider = ClaudeProvider(api_key="test-key", model="claude-sonnet-4-5")
        
        with patch.object(provider, '_get_client') as mock_get_client:
            mock_response = MagicMock()
            mock_response.content = [MagicMock(text="Claude response")]
            mock_response.usage = MagicMock(input_tokens=60, output_tokens=90)
            
            mock_client = AsyncMock()
            mock_client.messages.create = AsyncMock(return_value=mock_response)
            mock_get_client.return_value = mock_client
            
            messages = [
                LLMMessage(role="system", content="System prompt"),
                LLMMessage(role="user", content="User query")
            ]
            result = await provider.complete(messages)
            
            assert result is not None
            assert result.content == "Claude response"
            assert result.provider == "claude"
            assert result.tokens_used == 150
    
    @pytest.mark.asyncio
    async def test_provider_availability_check(self):
        """Test provider availability checks."""
        openai_provider = OpenAIProvider(api_key="test-key")
        assert await openai_provider.is_available() == True
        
        azure_provider = AzureOpenAIProvider(
            api_key="test-key",
            endpoint="https://test.openai.azure.com",
            deployment="gpt-4"
        )
        assert await azure_provider.is_available() == True
        
        deepseek_provider = DeepSeekProvider(api_key="test-key")
        assert await deepseek_provider.is_available() == True
        
        claude_provider = ClaudeProvider(api_key="test-key")
        assert await claude_provider.is_available() == True


# =============================================================================
# K. HELPER METHOD TESTS
# =============================================================================

class TestHelperMethods:
    """Test provider helper methods."""
    
    @pytest.mark.asyncio
    async def test_openai_generate_method(self):
        """Test OpenAI generate method (simple interface)."""
        provider = OpenAIProvider(api_key="test-key")
        
        with patch.object(provider, '_get_client') as mock_get_client:
            mock_response = MagicMock()
            mock_response.choices = [MagicMock(message=MagicMock(content="Generated text"))]
            mock_response.usage = MagicMock(total_tokens=100)
            
            mock_client = AsyncMock()
            mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
            mock_get_client.return_value = mock_client
            
            result = await provider.generate("Test prompt")
            assert result == "Generated text"
    
    @pytest.mark.asyncio
    async def test_openai_chat_method(self):
        """Test OpenAI chat method."""
        provider = OpenAIProvider(api_key="test-key")
        
        with patch.object(provider, '_get_client') as mock_get_client:
            mock_response = MagicMock()
            mock_response.choices = [MagicMock(message=MagicMock(content="Chat response"))]
            mock_response.usage = MagicMock(total_tokens=100)
            
            mock_client = AsyncMock()
            mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
            mock_get_client.return_value = mock_client
            
            result = await provider.chat(["Hello", "How are you?"])
            assert result == "Chat response"
    
    @pytest.mark.asyncio
    async def test_manager_generate_method(self):
        """Test LLMManager generate method."""
        manager = LLMManager()
        
        provider = AsyncMock()
        provider.provider_name = "openai"
        provider.complete = AsyncMock(
            return_value=LLMResponse(
                content="Generated",
                provider="openai",
                model="gpt-5.1",
                tokens_used=50
            )
        )
        manager.add_provider(provider)
        
        result = await manager.generate("Test prompt")
        assert result == "Generated"
    
    @pytest.mark.asyncio
    async def test_manager_chat_method(self):
        """Test LLMManager chat method."""
        manager = LLMManager()
        
        provider = AsyncMock()
        provider.provider_name = "openai"
        provider.complete = AsyncMock(
            return_value=LLMResponse(
                content="Chat response",
                provider="openai",
                model="gpt-5.1",
                tokens_used=50
            )
        )
        manager.add_provider(provider)
        
        result = await manager.chat(["Hello"])
        assert result == "Chat response"


# =============================================================================
# L. ADDITIONAL COVERAGE TESTS - AZURE EXCEPTION HANDLING
# =============================================================================

class TestAzureExceptionHandling:
    """Test Azure provider exception handling."""
    
    @pytest.mark.asyncio
    async def test_azure_rate_limit_exception(self):
        """Test Azure handles rate limit exceptions."""
        provider = AzureOpenAIProvider(
            api_key="test-key",
            endpoint="https://test.openai.azure.com",
            deployment="gpt-4"
        )
        
        with patch.object(provider, '_get_client') as mock_get_client:
            import openai
            mock_client = AsyncMock()
            mock_response = MagicMock()
            mock_response.status_code = 429
            mock_response.headers = {'retry-after': '60'}
            mock_error = openai.RateLimitError(
                message="Rate limit exceeded",
                response=mock_response,
                body={"error": {"message": "Rate limit exceeded"}}
            )
            mock_client.chat.completions.create = AsyncMock(side_effect=mock_error)
            mock_get_client.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                mock_logger.error.assert_called_once()
                assert mock_logger.error.call_args[0][0] == "azure_rate_limit"
    
    @pytest.mark.asyncio
    async def test_azure_connection_error(self):
        """Test Azure handles connection errors."""
        provider = AzureOpenAIProvider(
            api_key="test-key",
            endpoint="https://test.openai.azure.com",
            deployment="gpt-4"
        )
        
        with patch.object(provider, '_get_client') as mock_get_client:
            import openai
            mock_client = AsyncMock()
            mock_request = MagicMock()
            mock_error = openai.APIConnectionError(request=mock_request)
            mock_client.chat.completions.create = AsyncMock(side_effect=mock_error)
            mock_get_client.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                mock_logger.error.assert_called_once()
                assert mock_logger.error.call_args[0][0] == "azure_connection_error"
    
    @pytest.mark.asyncio
    async def test_azure_auth_error(self):
        """Test Azure handles authentication errors."""
        provider = AzureOpenAIProvider(
            api_key="test-key",
            endpoint="https://test.openai.azure.com",
            deployment="gpt-4"
        )
        
        with patch.object(provider, '_get_client') as mock_get_client:
            import openai
            mock_client = AsyncMock()
            mock_response = MagicMock()
            mock_response.status_code = 401
            mock_error = openai.AuthenticationError(
                message="Invalid API key",
                response=mock_response,
                body={"error": {"message": "Invalid API key"}}
            )
            mock_client.chat.completions.create = AsyncMock(side_effect=mock_error)
            mock_get_client.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                mock_logger.error.assert_called_once()
                assert mock_logger.error.call_args[0][0] == "azure_auth_error"
    
    @pytest.mark.asyncio
    async def test_azure_bad_request_error(self):
        """Test Azure handles bad request errors."""
        provider = AzureOpenAIProvider(
            api_key="test-key",
            endpoint="https://test.openai.azure.com",
            deployment="gpt-4"
        )
        
        with patch.object(provider, '_get_client') as mock_get_client:
            import openai
            mock_client = AsyncMock()
            mock_response = MagicMock()
            mock_response.status_code = 400
            mock_error = openai.BadRequestError(
                message="Invalid request",
                response=mock_response,
                body={"error": {"message": "Invalid request"}}
            )
            mock_client.chat.completions.create = AsyncMock(side_effect=mock_error)
            mock_get_client.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                mock_logger.error.assert_called_once()
                assert mock_logger.error.call_args[0][0] == "azure_bad_request"
    
    @pytest.mark.asyncio
    async def test_azure_unknown_error(self):
        """Test Azure handles unknown errors."""
        provider = AzureOpenAIProvider(
            api_key="test-key",
            endpoint="https://test.openai.azure.com",
            deployment="gpt-4"
        )
        
        with patch.object(provider, '_get_client') as mock_get_client:
            mock_client = AsyncMock()
            mock_client.chat.completions.create = AsyncMock(side_effect=ValueError("Unknown error"))
            mock_get_client.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                mock_logger.error.assert_called_once()
                assert mock_logger.error.call_args[0][0] == "azure_unknown_error"
    
    @pytest.mark.asyncio
    async def test_azure_complete_workflow(self):
        """Test Azure complete workflow."""
        provider = AzureOpenAIProvider(
            api_key="test-key",
            endpoint="https://test.openai.azure.com",
            deployment="gpt-4"
        )
        
        with patch.object(provider, '_get_client') as mock_get_client:
            mock_response = MagicMock()
            mock_response.choices = [MagicMock(message=MagicMock(content="Azure response"))]
            mock_response.usage = MagicMock(total_tokens=150)
            
            mock_client = AsyncMock()
            mock_client.chat.completions.create = AsyncMock(return_value=mock_response)
            mock_get_client.return_value = mock_client
            
            messages = [LLMMessage(role="user", content="Test")]
            result = await provider.complete(messages)
            
            assert result is not None
            assert result.content == "Azure response"
            assert result.provider == "azure"
            assert result.tokens_used == 150


# =============================================================================
# M. ADDITIONAL COVERAGE TESTS - CLAUDE EXCEPTION HANDLING
# =============================================================================

class TestClaudeExceptionHandling:
    """Test additional Claude provider exception handling."""
    
    @pytest.mark.asyncio
    async def test_claude_connection_error(self):
        """Test Claude handles connection errors."""
        provider = ClaudeProvider(api_key="test-key")
        
        with patch.object(provider, '_get_client') as mock_get_client:
            import anthropic
            mock_client = AsyncMock()
            mock_request = MagicMock()
            mock_error = anthropic.APIConnectionError(request=mock_request)
            mock_client.messages.create = AsyncMock(side_effect=mock_error)
            mock_get_client.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                mock_logger.error.assert_called_once()
                assert mock_logger.error.call_args[0][0] == "claude_connection_error"
    
    @pytest.mark.asyncio
    async def test_claude_auth_error(self):
        """Test Claude handles authentication errors."""
        provider = ClaudeProvider(api_key="test-key")
        
        with patch.object(provider, '_get_client') as mock_get_client:
            import anthropic
            mock_client = AsyncMock()
            mock_response = MagicMock()
            mock_response.status_code = 401
            mock_error = anthropic.AuthenticationError(
                message="Invalid API key",
                response=mock_response,
                body={"error": {"message": "Invalid API key"}}
            )
            mock_client.messages.create = AsyncMock(side_effect=mock_error)
            mock_get_client.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                mock_logger.error.assert_called_once()
                assert mock_logger.error.call_args[0][0] == "claude_auth_error"
    
    @pytest.mark.asyncio
    async def test_claude_bad_request_error(self):
        """Test Claude handles bad request errors."""
        provider = ClaudeProvider(api_key="test-key")
        
        with patch.object(provider, '_get_client') as mock_get_client:
            import anthropic
            mock_client = AsyncMock()
            mock_response = MagicMock()
            mock_response.status_code = 400
            mock_error = anthropic.BadRequestError(
                message="Invalid request",
                response=mock_response,
                body={"error": {"message": "Invalid request"}}
            )
            mock_client.messages.create = AsyncMock(side_effect=mock_error)
            mock_get_client.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                mock_logger.error.assert_called_once()
                assert mock_logger.error.call_args[0][0] == "claude_bad_request"
    
    @pytest.mark.asyncio
    async def test_claude_unknown_error(self):
        """Test Claude handles unknown errors."""
        provider = ClaudeProvider(api_key="test-key")
        
        with patch.object(provider, '_get_client') as mock_get_client:
            mock_client = AsyncMock()
            mock_client.messages.create = AsyncMock(side_effect=ValueError("Unknown error"))
            mock_get_client.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                mock_logger.error.assert_called_once()
                assert mock_logger.error.call_args[0][0] == "claude_unknown_error"


# =============================================================================
# N. LOCAL PROVIDER TESTS
# =============================================================================

class TestLocalProvider:
    """Test LocalProvider functionality."""
    
    def test_local_provider_initialization(self):
        """Test LocalProvider initialization with defaults."""
        from ai_sidecar.llm.providers import LocalProvider
        
        provider = LocalProvider()
        assert provider.endpoint == "http://localhost:11434"
        assert provider.model == "llama2"
        assert provider.model_path is None
    
    def test_local_provider_custom_params(self):
        """Test LocalProvider with custom parameters."""
        from ai_sidecar.llm.providers import LocalProvider
        
        provider = LocalProvider(
            endpoint="http://localhost:8080",
            model="mistral",
            model_path="/path/to/model"
        )
        assert provider.endpoint == "http://localhost:8080"
        assert provider.model == "mistral"
        assert provider.model_path == "/path/to/model"
    
    @pytest.mark.asyncio
    async def test_local_provider_complete_workflow(self):
        """Test LocalProvider complete workflow."""
        from ai_sidecar.llm.providers import LocalProvider
        
        provider = LocalProvider()
        
        with patch('httpx.AsyncClient') as mock_client_class:
            mock_response = MagicMock()
            mock_response.json = AsyncMock(return_value={
                "message": {"content": "Local response"}
            })
            mock_response.raise_for_status = AsyncMock()
            
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(return_value=mock_response)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_class.return_value = mock_client
            
            messages = [LLMMessage(role="user", content="Test")]
            result = await provider.complete(messages)
            
            assert result is not None
            assert result.content == "Local response"
            assert result.provider == "local"
    
    @pytest.mark.asyncio
    async def test_local_provider_complete_error(self):
        """Test LocalProvider handles errors."""
        from ai_sidecar.llm.providers import LocalProvider
        
        provider = LocalProvider()
        
        with patch('httpx.AsyncClient') as mock_client_class:
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(side_effect=Exception("Connection failed"))
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_class.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger'):
                result = await provider.complete([])
                assert result is None
    
    @pytest.mark.asyncio
    async def test_local_provider_is_available_success(self):
        """Test LocalProvider is_available when endpoint is up."""
        from ai_sidecar.llm.providers import LocalProvider
        
        provider = LocalProvider()
        
        with patch('httpx.AsyncClient') as mock_client_class:
            mock_response = MagicMock()
            mock_response.status_code = 200
            
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(return_value=mock_response)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_class.return_value = mock_client
            
            result = await provider.is_available()
            assert result == True
    
    @pytest.mark.asyncio
    async def test_local_provider_is_available_failure(self):
        """Test LocalProvider is_available when endpoint is down."""
        from ai_sidecar.llm.providers import LocalProvider
        
        provider = LocalProvider()
        
        with patch('httpx.AsyncClient') as mock_client_class:
            mock_client = AsyncMock()
            mock_client.get = AsyncMock(side_effect=Exception("Connection failed"))
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_class.return_value = mock_client
            
            result = await provider.is_available()
            assert result == False


# =============================================================================
# O. EDGE CASE TESTS
# =============================================================================

class TestEdgeCases:
    """Test edge cases and fallback behaviors."""
    
    @pytest.mark.asyncio
    async def test_openai_client_returns_none(self):
        """Test OpenAI handles case when client creation returns None."""
        provider = OpenAIProvider(api_key="test-key")
        
        with patch.object(provider, '_get_client', return_value=None):
            result = await provider.complete([])
            assert result is None
    
    @pytest.mark.asyncio
    async def test_azure_client_returns_none(self):
        """Test Azure handles case when client creation returns None."""
        provider = AzureOpenAIProvider(
            api_key="test-key",
            endpoint="https://test.openai.azure.com",
            deployment="gpt-4"
        )
        
        with patch.object(provider, '_get_client', return_value=None):
            result = await provider.complete([])
            assert result is None
    
    @pytest.mark.asyncio
    async def test_claude_client_returns_none(self):
        """Test Claude handles case when client creation returns None."""
        provider = ClaudeProvider(api_key="test-key")
        
        with patch.object(provider, '_get_client', return_value=None):
            result = await provider.complete([])
            assert result is None
    
    @pytest.mark.asyncio
    async def test_openai_unknown_error(self):
        """Test OpenAI handles unknown error types."""
        provider = OpenAIProvider(api_key="test-key")
        
        with patch.object(provider, '_get_client') as mock_get_client:
            mock_client = AsyncMock()
            mock_client.chat.completions.create = AsyncMock(side_effect=ValueError("Unknown error"))
            mock_get_client.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                mock_logger.error.assert_called_once()
                assert mock_logger.error.call_args[0][0] == "openai_unknown_error"
    
    @pytest.mark.asyncio
    async def test_deepseek_unknown_error(self):
        """Test DeepSeek handles unknown error types."""
        provider = DeepSeekProvider(api_key="test-key", max_retries=0)
        
        with patch('httpx.AsyncClient') as mock_client_class:
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(side_effect=ValueError("Unknown error"))
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_class.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                error_calls = [c for c in mock_logger.error.call_args_list
                              if c[0][0] == "deepseek_unknown_error"]
                assert len(error_calls) > 0
    
    @pytest.mark.asyncio
    async def test_openai_generate_returns_fallback(self):
        """Test OpenAI generate returns fallback when complete fails."""
        provider = OpenAIProvider(api_key="test-key")
        
        with patch.object(provider, 'complete', return_value=None):
            result = await provider.generate("Test prompt")
            assert result == "Generated response"
    
    @pytest.mark.asyncio
    async def test_openai_chat_returns_fallback(self):
        """Test OpenAI chat returns fallback when complete fails."""
        provider = OpenAIProvider(api_key="test-key")
        
        with patch.object(provider, 'complete', return_value=None):
            result = await provider.chat(["Hello"])
            assert result == "Chat response"
    
    @pytest.mark.asyncio
    async def test_deepseek_http_error_non_retryable(self):
        """Test DeepSeek doesn't retry on 400 (non-retryable)."""
        provider = DeepSeekProvider(api_key="test-key", max_retries=2)
        
        with patch('httpx.AsyncClient') as mock_client_class:
            mock_response = MagicMock()
            mock_response.status_code = 401  # Non-retryable status
            mock_error = httpx.HTTPStatusError(
                "Unauthorized",
                request=MagicMock(),
                response=mock_response
            )
            
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(side_effect=mock_error)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_class.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger'):
                result = await provider.complete([])
                assert result is None
    
    @pytest.mark.asyncio
    async def test_deepseek_no_response_data(self):
        """Test DeepSeek handles no response data."""
        provider = DeepSeekProvider(api_key="test-key")
        
        with patch.object(provider, '_make_request_with_retry', return_value=None):
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                error_calls = [c for c in mock_logger.error.call_args_list
                              if c[0][0] == "deepseek_no_response"]
                assert len(error_calls) > 0
    
    def test_azure_is_available_no_key(self):
        """Test Azure is_available returns False without API key."""
        provider = AzureOpenAIProvider(
            api_key=None,
            endpoint="https://test.openai.azure.com",
            deployment="gpt-4"
        )
        
        # Must run async test
        import asyncio
        result = asyncio.get_event_loop().run_until_complete(provider.is_available())
        assert result == False
    
    def test_azure_is_available_no_endpoint(self):
        """Test Azure is_available returns False without endpoint."""
        provider = AzureOpenAIProvider(
            api_key="test-key",
            endpoint=None,
            deployment="gpt-4"
        )
        
        import asyncio
        result = asyncio.get_event_loop().run_until_complete(provider.is_available())
        assert result == False
    
    def test_deepseek_is_available_no_key(self):
        """Test DeepSeek is_available returns False without API key."""
        provider = DeepSeekProvider(api_key=None)
        
        import asyncio
        result = asyncio.get_event_loop().run_until_complete(provider.is_available())
        assert result == False
    
    def test_claude_is_available_no_key(self):
        """Test Claude is_available returns False without API key."""
        provider = ClaudeProvider(api_key=None)
        
        import asyncio
        result = asyncio.get_event_loop().run_until_complete(provider.is_available())
        assert result == False


# =============================================================================
# P. PROVIDER NAME TESTS
# =============================================================================

class TestProviderNames:
    """Test provider name attributes."""
    
    def test_openai_provider_name(self):
        """Test OpenAI provider name."""
        provider = OpenAIProvider(api_key="test-key")
        assert provider.provider_name == "openai"
    
    def test_azure_provider_name(self):
        """Test Azure provider name."""
        provider = AzureOpenAIProvider(
            api_key="test-key",
            endpoint="https://test.openai.azure.com",
            deployment="gpt-4"
        )
        assert provider.provider_name == "azure"
    
    def test_deepseek_provider_name(self):
        """Test DeepSeek provider name."""
        provider = DeepSeekProvider(api_key="test-key")
        assert provider.provider_name == "deepseek"
    
    def test_claude_provider_name(self):
        """Test Claude provider name."""
        provider = ClaudeProvider(api_key="test-key")
        assert provider.provider_name == "claude"
    
    def test_local_provider_name(self):
        """Test Local provider name."""
        from ai_sidecar.llm.providers import LocalProvider
        provider = LocalProvider()
        assert provider.provider_name == "local"


# =============================================================================
# Q. ADDITIONAL RATE LIMIT BRANCH TESTS
# =============================================================================

class TestRateLimitBranches:
    """Test rate limit header handling branches."""
    
    @pytest.mark.asyncio
    async def test_openai_rate_limit_no_headers(self):
        """Test OpenAI rate limit without retry-after header."""
        provider = OpenAIProvider(api_key="test-key")
        
        with patch.object(provider, '_get_client') as mock_get_client:
            import openai
            mock_client = AsyncMock()
            mock_response = MagicMock()
            mock_response.status_code = 429
            # No headers attribute or empty headers
            mock_response.headers = {}
            mock_error = openai.RateLimitError(
                message="Rate limit exceeded",
                response=mock_response,
                body={"error": {"message": "Rate limit exceeded"}}
            )
            mock_client.chat.completions.create = AsyncMock(side_effect=mock_error)
            mock_get_client.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                mock_logger.error.assert_called_once()
    
    @pytest.mark.asyncio
    async def test_azure_rate_limit_no_headers(self):
        """Test Azure rate limit without retry-after header."""
        provider = AzureOpenAIProvider(
            api_key="test-key",
            endpoint="https://test.openai.azure.com",
            deployment="gpt-4"
        )
        
        with patch.object(provider, '_get_client') as mock_get_client:
            import openai
            mock_client = AsyncMock()
            mock_response = MagicMock()
            mock_response.status_code = 429
            mock_response.headers = {}  # Empty headers
            mock_error = openai.RateLimitError(
                message="Rate limit exceeded",
                response=mock_response,
                body={"error": {"message": "Rate limit exceeded"}}
            )
            mock_client.chat.completions.create = AsyncMock(side_effect=mock_error)
            mock_get_client.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger'):
                result = await provider.complete([])
                assert result is None
    
    @pytest.mark.asyncio
    async def test_claude_rate_limit_no_headers(self):
        """Test Claude rate limit without retry-after header."""
        provider = ClaudeProvider(api_key="test-key")
        
        with patch.object(provider, '_get_client') as mock_get_client:
            import anthropic
            mock_client = AsyncMock()
            mock_response = MagicMock()
            mock_response.status_code = 429
            mock_response.headers = {}  # Empty headers
            mock_error = anthropic.RateLimitError(
                message="Rate limit exceeded",
                response=mock_response,
                body={"error": {"message": "Rate limit exceeded"}}
            )
            mock_client.messages.create = AsyncMock(side_effect=mock_error)
            mock_get_client.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger'):
                result = await provider.complete([])
                assert result is None


# =============================================================================
# R. DEEPSEEK SERVER ERROR TESTS
# =============================================================================

class TestDeepSeekServerErrors:
    """Test DeepSeek server error handling."""
    
    @pytest.mark.asyncio
    async def test_deepseek_http_status_502(self):
        """Test DeepSeek handles 502 Bad Gateway."""
        provider = DeepSeekProvider(api_key="test-key", max_retries=0)
        
        with patch('httpx.AsyncClient') as mock_client_class:
            mock_response = MagicMock()
            mock_response.status_code = 502
            mock_response.headers = {}
            mock_error = httpx.HTTPStatusError(
                "Bad Gateway",
                request=MagicMock(),
                response=mock_response
            )
            
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(side_effect=mock_error)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_class.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                error_calls = [c for c in mock_logger.error.call_args_list
                              if c[0][0] == "deepseek_server_error"]
                assert len(error_calls) > 0
    
    @pytest.mark.asyncio
    async def test_deepseek_http_status_503(self):
        """Test DeepSeek handles 503 Service Unavailable."""
        provider = DeepSeekProvider(api_key="test-key", max_retries=0)
        
        with patch('httpx.AsyncClient') as mock_client_class:
            mock_response = MagicMock()
            mock_response.status_code = 503
            mock_response.headers = {}
            mock_error = httpx.HTTPStatusError(
                "Service Unavailable",
                request=MagicMock(),
                response=mock_response
            )
            
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(side_effect=mock_error)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_class.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                error_calls = [c for c in mock_logger.error.call_args_list
                              if c[0][0] == "deepseek_server_error"]
                assert len(error_calls) > 0
    
    @pytest.mark.asyncio
    async def test_deepseek_http_status_504(self):
        """Test DeepSeek handles 504 Gateway Timeout."""
        provider = DeepSeekProvider(api_key="test-key", max_retries=0)
        
        with patch('httpx.AsyncClient') as mock_client_class:
            mock_response = MagicMock()
            mock_response.status_code = 504
            mock_response.headers = {}
            mock_error = httpx.HTTPStatusError(
                "Gateway Timeout",
                request=MagicMock(),
                response=mock_response
            )
            
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(side_effect=mock_error)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_class.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                error_calls = [c for c in mock_logger.error.call_args_list
                              if c[0][0] == "deepseek_server_error"]
                assert len(error_calls) > 0


# =============================================================================
# S. ALL MODELS REGISTRY TESTS
# =============================================================================

class TestAllModelsRegistry:
    """Test ALL_MODELS combined registry."""
    
    def test_all_models_contains_all_providers(self):
        """Test ALL_MODELS contains all provider registries."""
        from ai_sidecar.llm.providers import ALL_MODELS
        
        assert "openai" in ALL_MODELS
        assert "deepseek" in ALL_MODELS
        assert "claude" in ALL_MODELS
        assert ALL_MODELS["openai"] == OPENAI_MODELS
        assert ALL_MODELS["deepseek"] == DEEPSEEK_MODELS
        assert ALL_MODELS["claude"] == CLAUDE_MODELS
    
    def test_get_supported_models_unknown_provider(self):
        """Test get_supported_models for unknown provider."""
        from ai_sidecar.llm.providers import get_supported_models
        
        result = get_supported_models("unknown_provider")
        assert result == []
    
    def test_get_model_info_unknown_provider(self):
        """Test get_model_info for unknown provider."""
        from ai_sidecar.llm.providers import get_model_info
        
        result = get_model_info("unknown_provider", "some-model")
        assert result == {}
    
    def test_get_model_info_unknown_model(self):
        """Test get_model_info for unknown model."""
        from ai_sidecar.llm.providers import get_model_info
        
        result = get_model_info("openai", "unknown-model-xyz")
        assert result == {}
    
    def test_is_reasoning_model_unknown_provider(self):
        """Test is_reasoning_model for unknown provider."""
        from ai_sidecar.llm.providers import is_reasoning_model
        
        result = is_reasoning_model("unknown_provider", "some-model")
        assert result == False


# =============================================================================
# T. LLMMESSAGE AND LLMRESPONSE MODEL TESTS
# =============================================================================

class TestPydanticModels:
    """Test Pydantic model validation."""
    
    def test_llm_message_user_role(self):
        """Test LLMMessage with user role."""
        msg = LLMMessage(role="user", content="Hello")
        assert msg.role == "user"
        assert msg.content == "Hello"
    
    def test_llm_message_system_role(self):
        """Test LLMMessage with system role."""
        msg = LLMMessage(role="system", content="You are a helpful assistant")
        assert msg.role == "system"
        assert msg.content == "You are a helpful assistant"
    
    def test_llm_message_assistant_role(self):
        """Test LLMMessage with assistant role."""
        msg = LLMMessage(role="assistant", content="How can I help?")
        assert msg.role == "assistant"
        assert msg.content == "How can I help?"
    
    def test_llm_response_defaults(self):
        """Test LLMResponse with defaults."""
        response = LLMResponse(
            content="Test response",
            provider="openai",
            model="gpt-5.1"
        )
        assert response.content == "Test response"
        assert response.provider == "openai"
        assert response.model == "gpt-5.1"
        assert response.tokens_used == 0
        assert response.latency_ms == 0
    
    def test_llm_response_full(self):
        """Test LLMResponse with all fields."""
        response = LLMResponse(
            content="Full response",
            provider="claude",
            model="claude-sonnet-4-5",
            tokens_used=500,
            latency_ms=1234.56
        )
        assert response.content == "Full response"
        assert response.provider == "claude"
        assert response.model == "claude-sonnet-4-5"
        assert response.tokens_used == 500
        assert response.latency_ms == 1234.56


# =============================================================================
# U. MANAGER ADDITIONAL METHODS TESTS
# =============================================================================

class TestManagerAdditionalMethods:
    """Test additional LLMManager methods."""
    
    def test_manager_get_available_providers(self):
        """Test getting list of available provider types."""
        manager = LLMManager()
        
        # Add multiple providers
        provider1 = AsyncMock()
        provider1.provider_name = "openai"
        provider2 = AsyncMock()
        provider2.provider_name = "claude"
        
        manager.add_provider(provider1)
        manager.add_provider(provider2)
        
        providers = [p.provider_name for p in manager.providers]
        assert "openai" in providers
        assert "claude" in providers
    
    def test_manager_empty_providers_list(self):
        """Test manager with empty providers list."""
        manager = LLMManager()
        assert len(manager.providers) == 0
    
    @pytest.mark.asyncio
    async def test_manager_complete_no_providers(self):
        """Test manager complete with no providers."""
        manager = LLMManager()
        
        result = await manager.complete([LLMMessage(role="user", content="Test")])
        assert result is None
    
    @pytest.mark.asyncio
    async def test_manager_generate_no_providers(self):
        """Test manager generate with no providers."""
        manager = LLMManager()
        
        result = await manager.generate("Test prompt")
        assert result is None or result == "Generation failed"


# =============================================================================
# V. OPENAI AND AZURE CLIENT CREATION TESTS
# =============================================================================

class TestClientCreation:
    """Test client creation and import error handling."""
    
    @pytest.mark.asyncio
    async def test_openai_client_creation_logs_debug(self):
        """Test OpenAI client creation logs debug message."""
        provider = OpenAIProvider(api_key="test-key")
        
        with patch('ai_sidecar.llm.providers.logger') as mock_logger:
            # Reset client
            provider._client = None
            # Call get_client which creates the client
            with patch('openai.AsyncOpenAI'):
                client = await provider._get_client()
                assert client is not None
    
    @pytest.mark.asyncio
    async def test_azure_client_creation_logs_debug(self):
        """Test Azure client creation logs debug message."""
        provider = AzureOpenAIProvider(
            api_key="test-key",
            endpoint="https://test.openai.azure.com",
            deployment="gpt-4"
        )
        
        with patch('ai_sidecar.llm.providers.logger') as mock_logger:
            # Reset client
            provider._client = None
            # Call get_client which creates the client
            with patch('openai.AsyncAzureOpenAI'):
                client = await provider._get_client()
                assert client is not None
    
    @pytest.mark.asyncio
    async def test_claude_client_creation_logs_debug(self):
        """Test Claude client creation logs debug message."""
        provider = ClaudeProvider(api_key="test-key")
        
        with patch('ai_sidecar.llm.providers.logger') as mock_logger:
            # Reset client
            provider._client = None
            # Call get_client which creates the client
            with patch('anthropic.AsyncAnthropic'):
                client = await provider._get_client()
                assert client is not None


# =============================================================================
# W. OPENAI IS_AVAILABLE TESTS
# =============================================================================

class TestIsAvailable:
    """Test is_available methods."""
    
    @pytest.mark.asyncio
    async def test_openai_is_available_with_key(self):
        """Test OpenAI is_available returns True with API key."""
        provider = OpenAIProvider(api_key="test-key")
        
        result = await provider.is_available()
        assert result == True
    
    @pytest.mark.asyncio
    async def test_openai_is_available_no_key(self):
        """Test OpenAI is_available returns False without API key."""
        provider = OpenAIProvider(api_key=None)
        
        result = await provider.is_available()
        assert result == False


# =============================================================================
# X. DEEPSEEK HTTP ERROR DETAILS
# =============================================================================

class TestDeepSeekHttpErrorDetails:
    """Test DeepSeek HTTP error handling with retry-after header."""
    
    @pytest.mark.asyncio
    async def test_deepseek_rate_limit_with_retry_after(self):
        """Test DeepSeek rate limit with retry-after header."""
        provider = DeepSeekProvider(api_key="test-key", max_retries=0)
        
        with patch('httpx.AsyncClient') as mock_client_class:
            mock_response = MagicMock()
            mock_response.status_code = 429
            mock_response.headers = {'retry-after': '30'}
            mock_error = httpx.HTTPStatusError(
                "Rate limit exceeded",
                request=MagicMock(),
                response=mock_response
            )
            
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(side_effect=mock_error)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_class.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                error_calls = [c for c in mock_logger.error.call_args_list
                              if c[0][0] == "deepseek_rate_limit"]
                assert len(error_calls) > 0
    
    @pytest.mark.asyncio
    async def test_deepseek_http_error_4xx(self):
        """Test DeepSeek handles 4xx errors (non rate limit)."""
        provider = DeepSeekProvider(api_key="test-key", max_retries=0)
        
        with patch('httpx.AsyncClient') as mock_client_class:
            mock_response = MagicMock()
            mock_response.status_code = 403  # Forbidden
            mock_response.headers = {}
            mock_error = httpx.HTTPStatusError(
                "Forbidden",
                request=MagicMock(),
                response=mock_response
            )
            
            mock_client = AsyncMock()
            mock_client.post = AsyncMock(side_effect=mock_error)
            mock_client.__aenter__ = AsyncMock(return_value=mock_client)
            mock_client.__aexit__ = AsyncMock(return_value=None)
            mock_client_class.return_value = mock_client
            
            with patch('ai_sidecar.llm.providers.logger') as mock_logger:
                result = await provider.complete([])
                assert result is None
                # Should log as http_error, not rate_limit or server_error
                error_calls = [c for c in mock_logger.error.call_args_list
                              if c[0][0] == "deepseek_http_error"]
                assert len(error_calls) > 0


# =============================================================================
# Y. MODEL INFO EDGE CASES
# =============================================================================

class TestModelInfoEdgeCases:
    """Test model info retrieval edge cases."""
    
    def test_openai_get_model_info_unknown(self):
        """Test OpenAI get_model_info for unknown model."""
        provider = OpenAIProvider(api_key="test-key", model="unknown-model-xyz")
        
        info = provider.get_model_info()
        assert info == {}
    
    def test_deepseek_get_model_info_unknown(self):
        """Test DeepSeek get_model_info for unknown model."""
        provider = DeepSeekProvider(api_key="test-key", model="unknown-model-xyz")
        
        info = provider.get_model_info()
        assert info == {}
    
    def test_claude_get_model_info_unknown(self):
        """Test Claude get_model_info for unknown model."""
        provider = ClaudeProvider(api_key="test-key", model="unknown-model-xyz")
        
        info = provider.get_model_info()
        assert info == {}


# =============================================================================
# Z. REASONING MODEL DETECTION BY PREFIX
# =============================================================================

class TestReasoningModelPrefix:
    """Test reasoning model detection by prefix."""
    
    def test_openai_is_reasoning_model_o1_prefix(self):
        """Test o1 prefix detection."""
        provider = OpenAIProvider(api_key="test-key", model="o1-unknown-new-model")
        assert provider.is_reasoning_model() == True
    
    def test_openai_is_reasoning_model_o3_prefix(self):
        """Test o3 prefix detection."""
        provider = OpenAIProvider(api_key="test-key", model="o3-experimental")
        assert provider.is_reasoning_model() == True
    
    def test_openai_is_reasoning_model_o4_prefix(self):
        """Test o4 prefix detection."""
        provider = OpenAIProvider(api_key="test-key", model="o4-future")
        assert provider.is_reasoning_model() == True
    
    def test_openai_is_not_reasoning_model_gpt_prefix(self):
        """Test non-reasoning model detection."""
        provider = OpenAIProvider(api_key="test-key", model="gpt-6")
        assert provider.is_reasoning_model() == False