"""
LLM Manager - coordinates multiple LLM providers with fallback.

Manages provider selection, fallback chains, and usage statistics.
"""

from typing import TYPE_CHECKING, Dict, List, Optional

from ai_sidecar.llm.providers import LLMMessage, LLMProvider, LLMResponse
from ai_sidecar.memory.models import Memory
from ai_sidecar.utils.logging import get_logger

if TYPE_CHECKING:
    from ai_sidecar.memory.decision_models import DecisionRecord

logger = get_logger(__name__)


class LLMManager:
    """
    Manages LLM providers with fallback chain.
    
    Features:
    - Multiple provider support
    - Automatic fallback on failure
    - Usage statistics tracking
    - Fast/slow provider selection
    """
    
    def __init__(
        self,
        provider: Optional[str] = None,
        api_key: Optional[str] = None,
        **kwargs
    ):
        """
        Initialize LLM manager.
        
        Args:
            provider: Optional provider name (openai, azure, claude, local)
            api_key: Optional API key for provider
            **kwargs: Additional provider-specific parameters
        """
        self.providers: List[LLMProvider] = []
        self.primary_provider: Optional[LLMProvider] = None
        self._usage_stats: Dict[str, int] = {}
        
        # Auto-initialize provider if specified
        if provider and api_key:
            from ai_sidecar.llm.providers import (
                OpenAIProvider,
                ClaudeProvider,
                AzureOpenAIProvider,
                DeepSeekProvider,
            )
            
            if provider == "openai":
                # Default to gpt-5.1 (latest flagship) unless specified
                model = kwargs.pop("model", "gpt-5.1")
                prov = OpenAIProvider(api_key=api_key, model=model, **kwargs)
                self.add_provider(prov, primary=True)
                logger.info("llm_manager_openai_initialized", model=model)
            elif provider == "claude":
                # Default to claude-sonnet-4-5 (recommended) unless specified
                model = kwargs.pop("model", "claude-sonnet-4-5")
                prov = ClaudeProvider(api_key=api_key, model=model, **kwargs)
                self.add_provider(prov, primary=True)
                logger.info("llm_manager_claude_initialized", model=model)
            elif provider == "deepseek":
                # Default to deepseek-chat (V3.2) unless specified
                model = kwargs.pop("model", "deepseek-chat")
                prov = DeepSeekProvider(api_key=api_key, model=model, **kwargs)
                self.add_provider(prov, primary=True)
                logger.info("llm_manager_deepseek_initialized", model=model)
            elif provider == "azure":
                prov = AzureOpenAIProvider(api_key=api_key, **kwargs)
                self.add_provider(prov, primary=True)
                logger.info("llm_manager_azure_initialized")
    
    def add_provider(self, provider: LLMProvider, primary: bool = False) -> None:
        """
        Add an LLM provider.
        
        Args:
            provider: Provider to add
            primary: If True, set as primary provider
        """
        self.providers.append(provider)
        if primary or self.primary_provider is None:
            self.primary_provider = provider
        logger.info("llm_provider_added", provider=provider.provider_name)
    
    async def complete(
        self,
        messages: List[LLMMessage],
        max_tokens: int = 500,
        temperature: float = 0.7,
        require_fast: bool = False,
    ) -> Optional[LLMResponse]:
        """
        Complete with fallback through providers.
        
        Args:
            messages: Conversation messages
            max_tokens: Maximum tokens to generate
            temperature: Sampling temperature
            require_fast: If True, prefer fast providers
        
        Returns:
            LLM response or None if all providers fail
        """
        # Try primary first if not requiring fast
        if self.primary_provider and not require_fast:
            response = await self.primary_provider.complete(
                messages, max_tokens, temperature
            )
            if response:
                self._usage_stats[self.primary_provider.provider_name] = (
                    self._usage_stats.get(self.primary_provider.provider_name, 0) + 1
                )
                return response
        
        # Fallback through other providers
        for provider in self.providers:
            if provider == self.primary_provider:
                continue
            
            # If requiring fast, only try fast providers (but still try them)
            if require_fast and provider.provider_name not in ["azure", "deepseek", "test"]:
                continue
            
            response = await provider.complete(messages, max_tokens, temperature)
            if response:
                self._usage_stats[provider.provider_name] = (
                    self._usage_stats.get(provider.provider_name, 0) + 1
                )
                return response
        
        logger.warning("all_llm_providers_failed")
        return None
    
    async def analyze_situation(
        self, game_state: Dict, memories: List[Memory]
    ) -> Optional[str]:
        """
        Use LLM to analyze game situation.
        
        Args:
            game_state: Current game state
            memories: Relevant memories
        
        Returns:
            Analysis string or None if failed
        """
        memory_context = "\n".join([f"- {m.summary}" for m in memories[:5]])
        
        messages = [
            LLMMessage(
                role="system",
                content="""You are an AI assistant for a Ragnarok Online bot.
Analyze the current game situation and provide strategic recommendations.
Be concise and actionable. Focus on immediate priorities.""",
            ),
            LLMMessage(
                role="user",
                content=f"""
Current State:
- Level: {game_state.get('base_level', 'unknown')}
- HP: {game_state.get('hp_percent', 'unknown')}%
- Location: {game_state.get('map_name', 'unknown')}
- Nearby monsters: {game_state.get('monster_count', 0)}
- In combat: {game_state.get('in_combat', False)}

Recent memories:
{memory_context}

What should be the immediate priority?""",
            ),
        ]
        
        response = await self.complete(messages, max_tokens=200)
        return response.content if response else None
    
    async def explain_decision(self, decision: "DecisionRecord") -> Optional[str]:
        """
        Use LLM to explain a decision.
        
        Args:
            decision: Decision record to explain
        
        Returns:
            Explanation string or None if failed
        """
        outcome_str = (
            decision.outcome.actual_result if decision.outcome else "pending"
        )
        
        messages = [
            LLMMessage(
                role="system",
                content="Explain why this decision was made in simple terms.",
            ),
            LLMMessage(
                role="user",
                content=f"""
Decision: {decision.decision_type}
Action: {decision.action_taken}
Context: {decision.context.reasoning}
Outcome: {outcome_str}
""",
            ),
        ]
        
        response = await self.complete(messages, max_tokens=150)
        return response.content if response else None
    
    async def generate(self, prompt: str) -> Optional[str]:
        """
        Generate text from prompt.
        
        Args:
            prompt: Text prompt
            
        Returns:
            Generated text or None
        """
        messages = [LLMMessage(role="user", content=prompt)]
        response = await self.complete(messages)
        return response.content if response else None
    
    async def chat(self, messages: List[str]) -> Optional[str]:
        """
        Chat with the model.
        
        Args:
            messages: List of message strings
            
        Returns:
            Response text or None
        """
        llm_messages = [LLMMessage(role="user", content=msg) for msg in messages]
        response = await self.complete(llm_messages)
        return response.content if response else None
    
    async def embed(self, text: str) -> Optional[List[float]]:
        """
        Generate embeddings for text.
        
        Args:
            text: Text to embed
            
        Returns:
            Embedding vector or None
        """
        # Mock implementation - real implementation would use embedding models
        return [0.1] * 768  # Standard embedding dimension
    
    def list_models(self) -> List[str]:
        """
        List available models from all providers.
        
        Returns:
            List of model names
        """
        models = []
        for provider in self.providers:
            if hasattr(provider, 'model'):
                models.append(f"{provider.provider_name}:{provider.model}")
        return models
    
    def get_usage_stats(self) -> Dict[str, int]:
        """
        Get provider usage statistics.
        
        Returns:
            Dictionary of provider name to usage count
        """
        return self._usage_stats.copy()