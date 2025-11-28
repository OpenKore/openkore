# AI Sidecar for OpenKore God-Tier AI System

🤖 **Python-based AI decision engine** that communicates with OpenKore via ZeroMQ IPC.

## Overview

The AI Sidecar is a separate process that receives game state from OpenKore's AI_Bridge plugin, processes it through an AI decision engine, and returns actions to execute. This architecture provides:

- **Isolation**: AI processing doesn't block OpenKore's main loop
- **Flexibility**: Can use Python's ML/AI libraries (PyTorch, NumPy, etc.)
- **Graceful Degradation**: OpenKore continues if sidecar is unavailable
- **Modularity**: Easy to swap or upgrade AI components

## Architecture

```
┌─────────────────┐         ZeroMQ IPC         ┌─────────────────┐
│    OpenKore     │◄─────────REQ/REP─────────►│   AI Sidecar    │
│  (Perl Plugin)  │      tcp://127.0.0.1:5555  │    (Python)     │
└─────────────────┘                            └─────────────────┘
        │                                              │
        ▼                                              ▼
   Game State JSON                              Decision JSON
   - Character                                  - Actions []
   - Actors                                     - Fallback Mode
   - Inventory                                  - Confidence
   - Map Info                                   - Metadata
```

## Requirements

- **Python**: 3.10 or higher
- **System**: Linux, macOS, or Windows
- **Dependencies**: See `pyproject.toml`

### Python Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| pyzmq | ≥25.1.0 | ZeroMQ bindings for IPC |
| pydantic | ≥2.5.0 | Data validation |
| pydantic-settings | ≥2.1.0 | Configuration management |
| structlog | ≥23.2.0 | Structured logging |
| aiofiles | ≥23.2.0 | Async file operations |
| python-dotenv | ≥1.0.0 | Environment loading |
| pyyaml | ≥6.0.1 | YAML configuration |

## Installation

### 1. Create Virtual Environment

```bash
cd openkore-AI/ai_sidecar

# Create virtual environment
python3 -m venv .venv

# Activate it
source .venv/bin/activate  # Linux/macOS
# .venv\Scripts\activate   # Windows
```

### 2. Install Dependencies

```bash
# Install package in development mode
pip install -e .

# Or install dependencies directly
pip install -e ".[dev]"
```

### 3. Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit configuration as needed
nano .env
```

## Configuration

Configuration can be set via:
1. **Environment variables** (highest priority)
2. **`.env` file** (loaded automatically)
3. **`config.yaml`** (default values)

### Key Configuration Options

| Variable | Default | Description |
|----------|---------|-------------|
| `AI_ZMQ_BIND_ADDRESS` | `tcp://127.0.0.1:5555` | ZMQ socket address |
| `AI_ZMQ_RECV_TIMEOUT_MS` | `100` | Receive timeout (ms) |
| `AI_TICK_INTERVAL_MS` | `100` | Tick processor interval |
| `AI_LOG_LEVEL` | `INFO` | Log verbosity |
| `AI_DECISION_STUB_MODE` | `true` | Use stub engine (no ML) |

See `.env.example` for all options.

## Running the Sidecar

### Basic Usage

```bash
# Activate virtual environment first
source .venv/bin/activate

# Run the sidecar
python -m ai_sidecar.main
```

### With Custom Configuration

```bash
# Override via environment variables
AI_LOG_LEVEL=DEBUG AI_ZMQ_BIND_ADDRESS=tcp://0.0.0.0:5556 python -m ai_sidecar.main
```

### Expected Output

```
2024-01-01T12:00:00.000Z [INFO] ai_sidecar.main: Starting AI Sidecar v0.1.0
2024-01-01T12:00:00.001Z [INFO] ai_sidecar.ipc.zmq_server: ZMQ REP socket binding to tcp://127.0.0.1:5555
2024-01-01T12:00:00.002Z [INFO] ai_sidecar.main: AI Sidecar ready and waiting for connections
```

## Testing

### Run IPC Test

With the sidecar running in one terminal:

```bash
# In another terminal
python -m ai_sidecar.tests.test_ipc
```

This simulates OpenKore sending state updates and receiving decisions.

### Run Unit Tests

```bash
# Install test dependencies
pip install -e ".[test]"

# Run tests with pytest
pytest -v
```

## Project Structure

```
ai_sidecar/
├── __init__.py              # Package initialization
├── main.py                  # Entry point, async event loop
├── config.py                # Configuration management
├── config.yaml              # Default configuration
├── .env.example             # Environment template
├── pyproject.toml           # Package definition
│
├── ipc/                     # IPC layer
│   ├── __init__.py
│   └── zmq_server.py        # ZeroMQ REP server
│
├── core/                    # Core AI logic
│   ├── __init__.py
│   ├── state.py             # Game state models
│   ├── decision.py          # Decision engine
│   └── tick.py              # Tick processor
│
├── protocol/                # IPC protocol
│   ├── __init__.py
│   ├── messages.py          # Pydantic message models
│   └── schemas/             # JSON Schema definitions
│       ├── state_update.json
│       ├── decision_response.json
│       └── heartbeat.json
│
├── utils/                   # Utilities
│   ├── __init__.py
│   └── logging.py           # Structured logging
│
└── tests/                   # Test suite
    ├── __init__.py
    └── test_ipc.py          # IPC communication tests
```

## Message Protocol

### State Update (OpenKore → Sidecar)

```json
{
  "type": "state_update",
  "timestamp": 1701234567890,
  "tick": 12345,
  "payload": {
    "character": { ... },
    "actors": [ ... ],
    "inventory": [ ... ],
    "map": { ... },
    "ai_mode": 1
  }
}
```

### Decision Response (Sidecar → OpenKore)

```json
{
  "type": "decision",
  "tick": 12345,
  "actions": [
    { "type": "move", "x": 150, "y": 200, "priority": 1 },
    { "type": "attack", "target": 12345, "priority": 2 }
  ],
  "fallback_mode": "cpu",
  "confidence": 0.95
}
```

### Heartbeat (Bidirectional)

```json
{
  "type": "heartbeat",
  "timestamp": 1701234567890,
  "source": "sidecar",
  "status": "healthy",
  "stats": { ... }
}
```

## Extending the AI

### Custom Decision Engine

```python
from ai_sidecar.core.decision import DecisionEngine, DecisionResult
from ai_sidecar.core.state import GameState

class MyCustomEngine(DecisionEngine):
    """Custom AI decision engine."""
    
    async def decide(self, state: GameState) -> DecisionResult:
        # Your AI logic here
        actions = []
        
        # Example: Attack nearest monster
        nearest = state.get_nearest_monster()
        if nearest:
            actions.append(Action(
                type=ActionType.ATTACK,
                target=nearest.id,
                priority=1
            ))
        
        return DecisionResult(
            tick=state.tick,
            actions=actions,
            fallback_mode="gpu",
            confidence=0.9
        )
```

### Register Custom Engine

```python
# In main.py or custom entry point
from ai_sidecar.core.tick import TickProcessor
from my_engine import MyCustomEngine

tick_processor = TickProcessor(
    decision_engine=MyCustomEngine()
)
```

## Troubleshooting

### Connection Refused

```
ZMQ Error: Connection refused
```

**Solution**: Make sure the sidecar is running before OpenKore connects.

### Timeout Errors

```
⚠️  Timeout waiting for response
```

**Solution**: Increase `AI_ZMQ_RECV_TIMEOUT_MS` in configuration.

### Module Not Found

```
ModuleNotFoundError: No module named 'ai_sidecar'
```

**Solution**: Install package with `pip install -e .` from the ai_sidecar directory.

## Performance Considerations

- **Tick Interval**: Default 100ms (10 ticks/sec). Adjust based on server tick rate.
- **Processing Time**: Keep decision processing under 80ms to avoid warnings.
- **Memory**: Default limit 512MB. Adjust `AI_MAX_MEMORY_MB` if using larger models.
- **Batch Processing**: Consider batching state history for pattern recognition.

## License

MIT License - See LICENSE file in repository root.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with tests
4. Submit a pull request

---

**Part of the God-Tier AI System for OpenKore**