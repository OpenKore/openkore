"""
LLM Manager - coordinates multiple LLM providers with fallback.

Manages provider selection, fallback chains, and usage statistics.
"""

from typing import Dict, List, Optional

from ai_sidecar.llm.providers import LLMMessage, LLMProvider, LLMResponse
from ai_sidecar.memory.models import Memory
from ai_sidecar.utils.logging import get_logger

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
    
    def __init__(self):
        """Initialize LLM manager."""
        self.providers: List[LLMProvider] = []
        self.primary_provider: Optional[LLMProvider] = None
        self._usage_stats: Dict[str, int] = {}
    
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
            
            if require_fast and provider.provider_name in ["azure", "deepseek"]:
                # These are typically faster
                pass
            elif require_fast:
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
        
        response = await self.complete(messages, max_tokens=200, require_fast=True)
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
    
    def get_usage_stats(self) -> Dict[str, int]:
        """
        Get provider usage statistics.
        
        Returns:
            Dictionary of provider name to usage count
        """
        return self._usage_stats.copy()