# Memory and Learning Systems (Phase 8)

## Overview

The God-Tier RO AI implements a three-tier memory architecture with self-learning capabilities, enabling adaptive behavior through experience replay and strategy evolution.

## Architecture

### Three-Tier Memory System

```
┌─────────────────────────────────────┐
│     Working Memory (RAM)            │
│  - Fast access (~100ms)             │
│  - LRU eviction                     │
│  - 1000 items max                   │
│  - Current session only             │
└─────────────────────────────────────┘
              ↓ Consolidation
┌─────────────────────────────────────┐
│   Session Memory (Redis/DragonflyDB)│
│  - Very fast (~1ms)                 │
│  - TTL-based expiration             │
│  - Cross-session persistence        │
│  - Type-based indexing              │
└─────────────────────────────────────┘
              ↓ Important memories
┌─────────────────────────────────────┐
│  Persistent Memory (SQLite)         │
│  - Permanent storage (~10ms)        │
│  - Strategy learning                │
│  - Pattern discovery                │
│  - Entity relationships             │
└─────────────────────────────────────┘
```

## Memory Types

- **EVENT**: Game events (combat, NPC interaction)
- **DECISION**: AI decisions with context
- **OUTCOME**: Decision results
- **PATTERN**: Discovered patterns
- **STRATEGY**: Learned strategies
- **ENTITY**: Player/NPC/monster profiles
- **LOCATION**: Map area knowledge
- **ECONOMIC**: Market and price data

## Memory Importance

- **TRIVIAL**: Decays in minutes (high decay rate 3.0x)
- **NORMAL**: Decays in hours (normal decay rate 1.0x)
- **IMPORTANT**: Decays in days (low decay rate 0.3x)
- **CRITICAL**: Never decays

## Self-Learning

### Decision Recording
```python
# Record a decision
record_id = await learning_engine.record_decision(
    decision_type="combat",
    action={"skill_id": 5, "target": 123},
    context=DecisionContext(
        game_state_snapshot={"hp": 80},
        available_options=["attack", "flee"],
        considered_factors=["hp_level", "monster_type"],
        confidence_level=0.8,
        reasoning="Safe to engage"
    )
)

# Later, record outcome
await learning_engine.record_outcome(
    record_id,
    success=True,
    actual_result={"damage": 500},
    reward_signal=0.8
)
```

### Experience Replay
```python
# Periodically replay past decisions
stats = await learning_engine.experience_replay(batch_size=20)
# Returns: {'strategies_updated': 3, 'patterns_found': 1}
```

### Strategy Selection
```python
# Get best action based on learned strategies
options = [
    {"strategy": "aggressive", "action": "attack"},
    {"strategy": "defensive", "action": "flee"}
]
best_action, confidence = await learning_engine.get_best_action(
    "combat", 
    options
)
```

## LLM Integration

### Supported Providers
- **OpenAI**: GPT-4o-mini, GPT-4
- **Azure OpenAI**: Enterprise deployments
- **DeepSeek**: Cost-effective alternative
- **Claude**: Anthropic models

### Configuration
```bash
# OpenAI
OPENAI_API_KEY=sk-...

# Azure OpenAI
AZURE_OPENAI_KEY=...
AZURE_OPENAI_ENDPOINT=https://....openai.azure.com
AZURE_OPENAI_DEPLOYMENT=gpt-4

# DeepSeek
DEEPSEEK_API_KEY=...

# Claude
ANTHROPIC_API_KEY=sk-ant-...
```

### Usage
```python
# LLM manager automatically tries providers in order
response = await llm_manager.complete(
    messages=[
        LLMMessage(role="system", content="You are a game AI"),
        LLMMessage(role="user", content="What should I do?")
    ],
    max_tokens=200,
    require_fast=True  # Prefer fast providers
)

# Situation analysis
analysis = await llm_manager.analyze_situation(
    game_state={"hp": 50, "in_combat": True},
    memories=recent_memories
)
```

## Memory Consolidation

Automatic consolidation runs every 5 minutes:
1. Apply decay to working memory
2. Move frequently accessed → Session memory
3. Move important memories → Persistent storage
4. Remove forgotten memories (strength < 0.1)

## Performance

- **Working Memory**: O(1) access, O(log n) eviction
- **Session Memory**: O(1) access via Redis
- **Persistent Memory**: O(log n) with SQLite indices
- **Memory overhead**: ~1KB per memory on average
- **Consolidation**: <50ms for typical workloads

## Testing

```bash
# Run memory tests
pytest tests/test_memory_models.py -v
pytest tests/test_working_memory.py -v
pytest tests/test_persistent_memory.py -v
pytest tests/test_memory_manager.py -v
pytest tests/test_learning_engine.py -v
pytest tests/test_llm_providers.py -v
pytest tests/test_integration_memory.py -v
```

## Files

- `models.py`: Memory data structures (134 lines)
- `decision_models.py`: Decision tracking models (64 lines)
- `working_memory.py`: RAM-based storage (213 lines)
- `session_memory.py`: Redis-backed storage (219 lines)
- `persistent_memory.py`: SQLite storage (395 lines)
- `manager.py`: Three-tier coordinator (280 lines)

## LLM Files

- `llm/providers.py`: Provider implementations (355 lines)
- `llm/manager.py`: Provider coordination (173 lines)

## Learning Files

- `learning/engine.py`: Self-learning engine (312 lines)

Total: ~2,145 lines across 9 files (all < 500 lines each)