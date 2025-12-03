# 🎮 God-Tier RO AI Bot - AI Sidecar

**Revolutionary AI system for Ragnarok Online that transforms OpenKore into a sophisticated, adaptive, and human-like autonomous player.**

[![Python](https://img.shields.io/badge/Python-3.12+-blue.svg)](https://www.python.org/)
[![Tests](https://img.shields.io/badge/Tests-637%20passing-brightgreen.svg)](tests/)
[![Coverage](https://img.shields.io/badge/Coverage-55.23%25-yellow.svg)](tests/)
[![License](https://img.shields.io/badge/License-GPLv2-blue.svg)](../LICENSE)

---

## 📖 Table of Contents

1. [Project Overview](#-project-overview)
2. [Quick Start](#-quick-start)
3. [Compute Backends](#-compute-backends)
4. [Configuration Guide](#-configuration-guide)
5. [Usage Examples](#-usage-examples)
6. [Testing](#-testing)
7. [Troubleshooting](#-troubleshooting)
8. [Features Overview](#-features-overview)
9. [Documentation](#-documentation)
10. [License & Credits](#-license--credits)

---

## 🎯 Project Overview

### What is God-Tier RO AI?

God-Tier RO AI is a **Python-based AI decision engine** that transforms the traditional OpenKore bot into an intelligent, adaptive, and human-like autonomous player. Using a modern **sidecar architecture**, it communicates with OpenKore via ZeroMQ IPC to provide enterprise-grade AI capabilities while maintaining full compatibility with OpenKore's proven game protocol handling.

### Why "God-Tier"?

| Traditional Bots | God-Tier AI |
|------------------|-------------|
| ❌ Rigid, predictable patterns | ✅ Adaptive behavior with randomization |
| ❌ Simple rule-based decisions | ✅ ML/LLM-powered strategic thinking |
| ❌ No memory of past events | ✅ Three-tier memory system (RAM/DragonflyDB/SQLite) |
| ❌ Easy to detect | ✅ Advanced anti-detection with human-like variance |
| ❌ Limited to basic tasks | ✅ Full lifecycle automation from Novice to Endgame |
| ❌ No social interaction | ✅ Natural chat, party coordination, guild management |

### Key Features

#### 🧠 **Intelligence & Learning**
- **Adaptive Behavior**: Dynamically adjusts tactics based on game conditions
- **Predictive Decision-Making**: ML models forecast outcomes before acting
- **Self-Learning**: Reinforcement learning from gameplay experience
- **Context Awareness**: Holistic understanding beyond immediate surroundings

#### 💾 **Memory System**
- **Working Memory**: Immediate context in RAM (~1000 items, <0.1ms access)
- **Session Memory**: Recent history in DragonflyDB (24h TTL, 0.5-2ms access)
- **Persistent Memory**: Long-term knowledge in SQLite (permanent storage)

#### ⚔️ **Combat Excellence**
- **6 Tactical Roles**: Tank, DPS Melee, DPS Ranged, Healer, Support, Hybrid
- **45+ Job Optimizations**: Specialized AI for each job class
- **Element/Race Effectiveness**: Smart targeting based on weaknesses
- **Emergency Protocols**: Auto-flee, heal, and defensive positioning

#### 🚀 **Autonomy**
- **Full Lifecycle**: Auto-leveling from Novice to Endgame
- **Stat Distribution**: Intelligent stat allocation per build
- **Skill Allocation**: Auto-learn optimal skills for your class
- **Quest Completion**: Navigate and complete quests autonomously

#### 🥷 **Stealth & Anti-Detection**
- **Timing Randomization**: Gaussian noise on action delays (150ms variance)
- **Movement Humanization**: Bezier curves, pauses, path deviations
- **Behavior Imperfections**: Intentional 5-10% suboptimal choices
- **GM Detection**: Alert and defensive behavior when GMs nearby
- **Session Management**: Auto-breaks, max play hours, human schedules

#### 🤝 **Social Features**
- **Natural Chat**: LLM-powered or template-based conversations
- **Party Coordination**: Healer awareness, tank support, formation
- **Guild Management**: Automated guild activities and coordination
- **MVP Hunting**: Collaborative boss hunting with loot sharing

#### 💰 **Economy**
- **Market Intelligence**: Price tracking and trend analysis
- **Vending Optimization**: Auto-pricing based on market conditions
- **Trading Strategy**: Buy low, sell high arbitrage detection
- **Auto-Buying**: Automated NPC and player shop purchases

### System Statistics

```
Total Lines of Code:     77,760 Python
Test Suites:            637 tests (100% pass rate)
Test Coverage:          55.23% (target: 90%)
Supported Jobs:         45+
LLM Providers:          4 (OpenAI, Azure, DeepSeek, Claude)
Compute Backends:       4 (CPU, GPU, ML, LLM)
```

---

## 🚀 Quick Start

### Prerequisites

Before you begin, ensure you have:

- ✅ **Python 3.12+** (Python 3.11+ also supported)
- ✅ **OpenKore** installed and configured
- ✅ **Git** for cloning repositories
- ✅ **2GB+ RAM** minimum, 4GB+ recommended
- ⚠️ **DragonflyDB or Redis** (optional, for memory features)
- ⚠️ **NVIDIA GPU with CUDA** (optional, for GPU mode)
- ⚠️ **LLM API key** (optional, for LLM features)

### Installation

#### 1. Clone the Repository

```bash
cd openkore-AI
```

If you need to clone the repository first:
```bash
git clone https://github.com/OpenKore/openkore.git openkore-AI
cd openkore-AI
```

#### 2. Create Virtual Environment

```bash
cd ai_sidecar
python3 -m venv .venv

# Activate virtual environment
source .venv/bin/activate  # Linux/macOS
# On Windows: .venv\Scripts\activate
```

#### 3. Install Dependencies

```bash
# Upgrade pip first
pip install --upgrade pip

# Install AI Sidecar package
pip install -r requirements.txt

# Verify installation
python -c "import zmq, pydantic; print('✅ Dependencies installed successfully!')"
```

#### 4. Configure the AI

```bash
# Copy environment template
cp .env.example .env

# Edit with your settings
nano .env  # or use your preferred editor
```

**Minimal `.env` configuration:**
```bash
# Core Settings
AI_DEBUG_MODE=false
AI_LOG_LEVEL=INFO

# ZeroMQ Communication
AI_ZMQ_BIND_ADDRESS=tcp://127.0.0.1:5555

# Decision Engine (CPU mode by default)
AI_DECISION_ENGINE_TYPE=rule_based
```

#### 5. Run the AI Sidecar

**Terminal 1 - Start AI Sidecar:**
```bash
cd ai_sidecar
source .venv/bin/activate
python main.py
```

**Expected output:**
```
[INFO] AI Sidecar starting v3.0.0
[INFO] ZeroMQ server binding to tcp://127.0.0.1:5555
✅ AI Sidecar ready! Listening on: tcp://127.0.0.1:5555
```

#### 6. Start OpenKore

**Terminal 2 - Start OpenKore:**
```bash
cd ../
./start.pl  # Linux/macOS
# On Windows: start.exe
```

**Expected output:**
```
[GodTier] AI Bridge plugin loaded
[GodTier] Connected to AI sidecar at tcp://127.0.0.1:5555
✅ God-Tier AI activated!
```

### Verification

✅ **Success indicators:**
- AI Sidecar shows "✅ AI Sidecar ready!"
- OpenKore shows "[GodTier] Connected to AI sidecar"
- No connection errors in either terminal
- Bot begins making AI-assisted decisions in-game

🎉 **Congratulations!** Your God-Tier RO AI is now running in CPU-only mode. Continue reading to enable advanced features.

---

## ⚙️ Compute Backends

The AI Sidecar supports four compute backends for different use cases and hardware configurations.

### 🖥️ CPU-Only Mode (Default)

**Best for:** Getting started, limited hardware, maximum reliability, multiple bots

#### Features
- ✅ **Zero dependencies** - works on any hardware
- ✅ **Fast decisions** - 2-5ms average latency
- ✅ **Low resource usage** - 10-25% CPU, 500MB-1GB RAM
- ✅ **Deterministic behavior** - consistent and predictable
- ✅ **Battle-tested** - most stable backend

#### Quick Setup

No additional configuration needed! CPU mode works out of the box.

```bash
# Just run the AI Sidecar
python main.py
```

#### Configuration

```yaml
# config.yaml (optional customization)
backend:
  primary: cpu
  
behaviors:
  combat:
    enabled: true
    tactical_mode: rule_based
  
anti_detection:
  enabled: true
```

**When to use:**
- 🎯 Local development and testing
- 🎯 Low-end VPS or cloud instances
- 🎯 Running multiple bot instances
- 🎯 Maximum stability requirement
- 🎯 You don't have GPU or LLM API access

---

### 🎮 GPU Mode (CUDA Acceleration)

**Best for:** High-performance ML inference, neural network decisions, batch processing

#### Hardware Requirements
- **GPU:** NVIDIA GPU with CUDA support
  - Minimum: GTX 1060 (6GB VRAM)
  - Recommended: RTX 3060+ (8GB VRAM)
  - Optimal: RTX 4070+ (12GB VRAM)
- **CPU:** 4+ cores @ 2.5GHz
- **RAM:** 8GB minimum, 16GB recommended
- **Storage:** 10GB for models

#### Performance
- **Decision Latency:** 8-15ms average
- **Throughput:** 60-120 decisions/second
- **GPU Usage:** 30-50%
- **Benefit:** 10-50x faster ML inference vs CPU

#### Setup Instructions

**Step 1: Install CUDA Toolkit**
```bash
# Ubuntu/Debian
wget https://developer.download.nvidia.com/compute/cuda/12.3.0/local_installers/cuda_12.3.0_545.23.08_linux.run
sudo sh cuda_12.3.0_545.23.08_linux.run

# Verify installation
nvcc --version
nvidia-smi
```

**Step 2: Install ONNX Runtime GPU**
```bash
source .venv/bin/activate
pip install onnxruntime-gpu
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
```

**Step 3: Configure GPU Backend**
```bash
# Set environment variable
export COMPUTE_BACKEND=gpu

# Run AI Sidecar
python main.py
```

Or edit `.env`:
```bash
COMPUTE_BACKEND=gpu
GPU_DEVICE_ID=0
GPU_MEMORY_FRACTION=0.5
```

#### Configuration

```yaml
# config.yaml
backend:
  primary: gpu
  fallback_chain: [cpu]  # Fallback to CPU if GPU unavailable
  
  gpu:
    device_id: 0
    memory_fraction: 0.5
    allow_growth: true

ml:
  model_path: ./models/
  batch_size: 32
  use_fp16: true  # Faster inference with half precision
```

---

### 🤖 LLM Mode - Multiple Providers

**Best for:** Strategic planning, natural chat, complex reasoning, human-like decisions

All 4 LLM providers are supported. Choose the one that fits your needs:

---

#### OpenAI SDK

**Best for:** Latest models, best quality, function calling

**Setup:**
1. Create account at [platform.openai.com](https://platform.openai.com)
2. Generate API key in Settings → API Keys
3. Add payment method

**Configuration:**
```bash
# .env
export COMPUTE_BACKEND=llm
export LLM_PROVIDER=openai
export OPENAI_API_KEY=sk-proj-xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
export OPENAI_MODEL=gpt-4o-mini  # or gpt-4-turbo-preview
```

**Run:**
```bash
python main.py
```

**Recommended Models:**
- `gpt-4o-mini` - **Fast, cost-effective** (recommended)
- `gpt-4-turbo-preview` - Most capable
- `gpt-3.5-turbo` - Budget option

**Pricing:**
- GPT-4o-mini: ~$0.15/$0.60 per 1M tokens (input/output)
- GPT-4-turbo: ~$10/$30 per 1M tokens
- Estimated: **$0.10-$0.50/hour** depending on usage

---

#### Azure OpenAI SDK

**Best for:** Enterprise, compliance, private endpoints, SLA guarantees

**Setup:**
1. Create Azure subscription at [portal.azure.com](https://portal.azure.com)
2. Create Azure OpenAI resource
3. Deploy a model (e.g., GPT-4)
4. Copy endpoint and keys

**Configuration:**
```bash
# .env
export COMPUTE_BACKEND=llm
export LLM_PROVIDER=azure
export AZURE_OPENAI_KEY=your_key_here
export AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
export AZURE_OPENAI_DEPLOYMENT=gpt-4
export AZURE_OPENAI_API_VERSION=2024-02-01
```

**Run:**
```bash
python main.py
```

**Benefits:**
- ✅ Enterprise security and compliance
- ✅ Private endpoints available
- ✅ SLA guarantees
- ✅ GDPR compliance
- ✅ Data stays in your region

**Pricing:** ~$0.03-0.06 per 1K tokens (similar to OpenAI)

---

#### DeepSeek SDK

**Best for:** Budget-conscious, high-volume, cost optimization (70% cheaper!)

**Setup:**
1. Create account at [platform.deepseek.com](https://platform.deepseek.com)
2. Generate API key
3. Add credit (starts at $5)

**Configuration:**
```bash
# .env
export COMPUTE_BACKEND=llm
export LLM_PROVIDER=deepseek
export DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
export DEEPSEEK_MODEL=deepseek-chat
```

**Run:**
```bash
python main.py
```

**Benefits:**
- ✅ **70% cheaper than OpenAI** (~$0.014/$0.028 per 1M tokens)
- ✅ Good performance on technical tasks
- ✅ Fast response times
- ✅ Chinese and English support

**Pricing:** ~$0.014/$0.028 per 1M tokens
**Estimated:** **$0.02-$0.10/hour** (10x cheaper than GPT-4)

---

#### Claude SDK (Anthropic)

**Best for:** Complex reasoning, safety-critical, long context, analysis

**Setup:**
1. Create account at [console.anthropic.com](https://console.anthropic.com)
2. Generate API key
3. Add payment method

**Configuration:**
```bash
# .env
export COMPUTE_BACKEND=llm
export LLM_PROVIDER=anthropic
export ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
export ANTHROPIC_MODEL=claude-3-haiku-20240307  # or claude-3-sonnet
```

**Run:**
```bash
python main.py
```

**Available Models:**
- `claude-3-haiku` - **Fast and affordable** (recommended)
- `claude-3-sonnet` - Balanced performance
- `claude-3-opus` - Most capable

**Benefits:**
- ✅ Excellent reasoning and analysis
- ✅ Strong safety features
- ✅ **200K token context window**
- ✅ Constitutional AI principles

**Pricing:**
- Haiku: ~$0.25/$1.25 per 1M tokens
- Sonnet: ~$3/$15 per 1M tokens
- Estimated: **$0.15-$0.80/hour**

---

### LLM Performance Comparison

| Provider | Latency | Cost (1M tokens) | Best Use Case |
|----------|---------|------------------|---------------|
| **OpenAI GPT-4o-mini** | 500-1000ms | $0.15/$0.60 | General purpose, balanced |
| **Azure OpenAI** | 500-1200ms | $0.03-0.06 | Enterprise, compliance |
| **DeepSeek** | 400-800ms | $0.014/$0.028 | **Budget, high volume** |
| **Claude Haiku** | 600-1000ms | $0.25/$1.25 | Reasoning, safety |

### LLM Configuration Examples

**Natural chat with GPT-4o-mini:**
```yaml
# config.yaml
llm:
  provider: openai
  model: gpt-4o-mini
  max_tokens: 150
  temperature: 0.8
  
behaviors:
  social:
    mode: llm
    chattiness: 0.3
    personality: friendly
```

**Strategic planning with Claude:**
```yaml
llm:
  provider: claude
  model: claude-3-sonnet
  
  strategy:
    enabled: true
    interval_seconds: 300  # Re-evaluate every 5 min
    max_tokens: 500
```

**Cost optimization with DeepSeek:**
```yaml
llm:
  provider: deepseek
  model: deepseek-chat
  
  cache:
    enabled: true
    ttl_seconds: 600  # Cache responses for 10 min
  
  rate_limits:
    requests_per_minute: 100
```

---

## 🔧 Configuration Guide

### Configuration Hierarchy

Configuration is loaded in this priority order (highest to lowest):
1. **Environment variables** (highest priority)
2. **`.env` file**
3. **`config.yaml`**
4. **Default values in code** (lowest priority)

### Basic Settings

#### config.yaml
```yaml
# General settings
general:
  app_name: "God-Tier-AI"
  debug: false
  log_level: INFO  # DEBUG, INFO, WARNING, ERROR, CRITICAL
  health_check_interval_s: 5.0

# IPC Settings
ipc:
  endpoint: "tcp://127.0.0.1:5555"
  recv_timeout_ms: 100
  tick_interval_ms: 200  # 5 decisions per second

# Compute Backend
compute_backend: "cpu"  # Options: cpu, gpu, llm

# Memory Settings (optional)
memory:
  backend: "dragonfly"  # Options: dragonfly, redis, none
  dragonfly:
    host: "localhost"
    port: 6379
```

### Environment Variables

```bash
# Backend selection
COMPUTE_BACKEND=llm         # cpu, gpu, or llm

# LLM Provider (when backend=llm)
LLM_PROVIDER=openai        # openai, azure, deepseek, anthropic

# API Keys
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...
DEEPSEEK_API_KEY=sk-...
AZURE_OPENAI_KEY=...
AZURE_OPENAI_ENDPOINT=https://...

# Memory Store (optional)
DRAGONFLY_HOST=localhost
DRAGONFLY_PORT=6379

# Debug
AI_LOG_LEVEL=INFO
AI_DEBUG_MODE=false
```

### DragonflyDB Setup (Optional)

DragonflyDB provides session memory for the AI (recent history, patterns, interactions).

**Using Docker (Recommended):**
```bash
docker run -d \
  --name openkore-dragonfly \
  -p 6379:6379 \
  --ulimit memlock=-1 \
  docker.dragonflydb.io/dragonflydb/dragonfly \
  --snapshot_cron="*/5 * * * *"

# Verify connection
docker ps | grep dragonfly
redis-cli -h localhost -p 6379 ping
# Should return: PONG
```

**Alternative: Use Redis:**
```bash
# Install Redis
sudo apt-get install redis-server

# Start Redis
sudo systemctl start redis
sudo systemctl enable redis

# Test connection
redis-cli ping
```

---

## 💡 Usage Examples

### Example 1: Basic Auto-Leveling Bot (CPU Mode)

Perfect for getting started, leveling characters, or running on low-end hardware.

```bash
# Terminal 1: Start AI Sidecar
cd ai_sidecar
source .venv/bin/activate
python main.py

# Terminal 2: Start OpenKore
cd ../
./start.pl
```

**Features enabled:**
- ✅ Auto-leveling with intelligent stat allocation
- ✅ Skill point auto-allocation per build
- ✅ Autonomous combat with tactical AI
- ✅ Item pickup and inventory management
- ✅ Auto-heal with potions

---

### Example 2: GPU-Accelerated Combat Bot

For high-performance ML-based target selection and combat decisions.

```bash
# Terminal 1: GPU mode
cd ai_sidecar
source .venv/bin/activate
export COMPUTE_BACKEND=gpu
python main.py

# Terminal 2: Start OpenKore
cd ../
./start.pl
```

**Benefits:**
- ⚡ 10-50x faster ML inference
- ⚡ Advanced pattern recognition
- ⚡ Real-time neural network decisions
- ⚡ Can handle multiple bots efficiently

---

### Example 3: LLM-Powered Strategic Bot (Claude)

For advanced decision-making, natural chat, and strategic planning.

```bash
# Terminal 1: Claude-powered AI
cd ai_sidecar
source .venv/bin/activate
export COMPUTE_BACKEND=llm
export LLM_PROVIDER=anthropic
export ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxx
python main.py

# Terminal 2: Start OpenKore
cd ../
./start.pl
```

**Features:**
- 🧠 Strategic planning every 5 minutes
- 🧠 Natural language chat with other players
- 🧠 Complex reasoning for quests
- 🧠 Adaptive tactics based on situation

---

### Example 4: Budget-Friendly LLM Bot (DeepSeek)

Same features as other LLM modes but 70% cheaper!

```bash
# Terminal 1: DeepSeek-powered AI
cd ai_sidecar
source .venv/bin/activate
export COMPUTE_BACKEND=llm
export LLM_PROVIDER=deepseek
export DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxx
python main.py

# Terminal 2: Start OpenKore
cd ../
./start.pl
```

**Cost:** ~$0.02-$0.10/hour (vs $0.10-$0.50/hour for OpenAI)

---

### Example 5: Multi-Bot Setup

Run multiple bots with a single AI Sidecar instance.

```bash
# Terminal 1: Shared AI Sidecar
cd ai_sidecar
source .venv/bin/activate
python main.py

# Terminal 2: Bot 1 (Priest - Support)
cd ../
./start.pl --character=Priest1 --ipc-endpoint=ipc:///tmp/bot1.sock

# Terminal 3: Bot 2 (Knight - Tank)
cd ../
./start.pl --character=Knight1 --ipc-endpoint=ipc:///tmp/bot2.sock

# Terminal 4: Bot 3 (Wizard - DPS)
cd ../
./start.pl --character=Wizard1 --ipc-endpoint=ipc:///tmp/bot3.sock
```

**Benefits:**
- 💰 Shared compute resources
- 💰 Single GPU for all bots
- 💰 Coordinated party gameplay
- 💰 Lower total resource usage

---

### Example 6: Maximum Stealth Mode

For avoiding detection with maximum anti-detection settings.

```bash
# Edit config.yaml first:
# anti_detection:
#   paranoia_level: extreme
#   timing_variance_ms: 250
#   session_max_continuous_hours: 3

cd ai_sidecar
source .venv/bin/activate
python main.py
```

**Features:**
- 🥷 Maximum timing randomization
- 🥷 Bezier curve movement
- 🥷 Intentional imperfections
- 🥷 Random breaks and pauses
- 🥷 GM detection and avoidance

---

## 🧪 Testing

### Run All Tests

```bash
cd ai_sidecar
source .venv/bin/activate

# Set PYTHONPATH to project root
export PYTHONPATH=/home/lot399/ai-mmorpg-world/openkore-AI

# Run all tests
pytest tests/ -v

# Expected output:
# ====== 637 passed in X seconds ======
```

### Run Specific Test Module

```bash
# Test combat AI
pytest tests/combat/test_combat_ai.py -v

# Test progression system
pytest tests/progression/test_lifecycle.py -v

# Test LLM integration
pytest tests/llm/test_providers.py -v
```

### Check Test Coverage

```bash
# Generate coverage report
pytest tests/ --cov=ai_sidecar --cov-report=html

# Open coverage report in browser
# File: htmlcov/index.html
xdg-open htmlcov/index.html  # Linux
open htmlcov/index.html      # macOS
start htmlcov/index.html     # Windows
```

**Current Coverage:** 55.23% (target: 90%)

### Verify Installation

```bash
# Check Python version
python --version  # Should be 3.12+

# Check dependencies
python -c "import zmq, pydantic, structlog; print('✅ All dependencies OK')"

# Check AI Sidecar version
python -c "import ai_sidecar; print(ai_sidecar.__version__)"
```

### Run Integration Tests

```bash
# Start AI Sidecar in one terminal
python main.py

# In another terminal, run integration tests
pytest tests/integration/ -v --integration
```

---

## 🔧 Troubleshooting

### Common Issues

#### ❌ Import Error: "No module named 'ai_sidecar'"

**Symptoms:**
```
ModuleNotFoundError: No module named 'ai_sidecar'
```

**Solution:**
```bash
# Ensure PYTHONPATH is set
export PYTHONPATH=/path/to/openkore-AI

# Or install in development mode
cd ai_sidecar
pip install -e .
```

---

#### ❌ ZeroMQ Connection Failed

**Symptoms:**
```
[GodTier] Failed to connect to AI sidecar at tcp://127.0.0.1:5555
```

**Solutions:**

1. **Ensure AI Sidecar is running:**
   ```bash
   cd ai_sidecar
   source .venv/bin/activate
   python main.py
   ```

2. **Check port availability:**
   ```bash
   # Linux/macOS
   netstat -tlnp | grep 5555
   
   # Windows
   netstat -ano | findstr :5555
   ```

3. **Try alternative endpoint:**
   ```bash
   # In .env
   AI_ZMQ_BIND_ADDRESS=tcp://0.0.0.0:5555
   ```

4. **Check firewall:**
   ```bash
   sudo ufw allow 5555/tcp
   ```

---

#### ❌ DragonflyDB Not Connecting

**Symptoms:**
```
ConnectionRefusedError: Could not connect to DragonflyDB at localhost:6379
```

**Solutions:**

1. **Start DragonflyDB:**
   ```bash
   docker run -d -p 6379:6379 docker.dragonflydb.io/dragonflydb/dragonfly
   ```

2. **Test connection:**
   ```bash
   redis-cli -h localhost -p 6379 ping
   # Should return: PONG
   ```

3. **Use fallback (disable session memory):**
   ```yaml
   # config.yaml
   memory:
     session:
       backend: none  # Disable session memory
   ```

---

#### ❌ LLM API Timeout

**Symptoms:**
```
TimeoutError: LLM API request timed out after 10 seconds
```

**Solutions:**

1. **Increase timeout:**
   ```yaml
   # config.yaml
   llm:
     timeout_seconds: 30
   ```

2. **Use faster model:**
   ```bash
   export OPENAI_MODEL=gpt-4o-mini  # Faster than gpt-4
   ```

3. **Enable fallback to CPU:**
   ```yaml
   backend:
     primary: llm
     fallback_chain: [cpu]  # Falls back to CPU if LLM times out
   ```

---

#### ⚠️ High CPU Usage

**Symptoms:**
- CPU usage consistently above 80%
- Slow system performance

**Solutions:**

```yaml
# config.yaml - Reduce tick rate
general:
  tick_rate_ms: 300  # Slower but less CPU (default: 200)

# Disable expensive features
behaviors:
  adaptive:
    enabled: false
  consciousness:
    enabled: false
```

---

#### ⚠️ Memory Growth / Leak

**Symptoms:**
- RAM usage grows over time
- System becomes sluggish

**Solutions:**

```yaml
# config.yaml - Aggressive memory cleanup
memory:
  working:
    max_entries: 500          # Reduce buffer size
    cleanup_interval_s: 60    # Clean more frequently

  session:
    ttl_hours: 12             # Shorter retention
```

---

#### ⚠️ Out of Memory with LLM Mode

**Symptoms:**
```
MemoryError: Cannot allocate memory for LLM context
```

**Solutions:**

```bash
# Use streaming mode
export LLM_STREAMING=true

# Reduce context window
export LLM_MAX_TOKENS=2048  # Instead of 4096

# Use smaller model
export OPENAI_MODEL=gpt-4o-mini  # Instead of gpt-4
```

---

### Debug Mode

Enable comprehensive logging for troubleshooting:

```bash
# Enable debug mode
export AI_DEBUG_MODE=true
export AI_LOG_LEVEL=DEBUG

# Run AI Sidecar
python main.py

# Logs will show:
# - Every state update received
# - Decision processing steps
# - Action generation reasoning
# - Memory operations
# - LLM API calls with full context
```

---

### Getting Help

If you're still experiencing issues:

1. **Check logs:** Look for error messages in the AI Sidecar terminal
2. **Search documentation:** See [Full Documentation](../docs/GODTIER-RO-AI-DOCUMENTATION.md)
3. **GitHub Issues:** Report bugs at [GitHub Issues](https://github.com/OpenKore/openkore/issues)
4. **Discord Community:** Get real-time help on [Discord](https://discord.com/invite/hdAhPM6)
5. **OpenKore Forum:** Post questions on [Forums](https://forums.openkore.com/)

---

## ✨ Features Overview

### Core AI Capabilities

| Feature | Description | Status |
|---------|-------------|--------|
| **Adaptive Behavior** | Dynamically adjusts tactics based on game conditions | ✅ Complete |
| **Predictive Decision-Making** | ML models forecast outcomes before acting | ✅ Complete |
| **Self-Learning** | Reinforcement learning from gameplay experience | ✅ Complete |
| **Context Awareness** | Holistic understanding beyond immediate surroundings | ✅ Complete |
| **Behavior Randomization** | Human-like variance to avoid detection | ✅ Complete |
| **GM Detection** | Alert and defensive behavior when GMs nearby | ✅ Complete |

### Combat System

| Feature | Description | Status |
|---------|-------------|--------|
| **6 Tactical Roles** | Tank, DPS Melee, DPS Ranged, Healer, Support, Hybrid | ✅ Complete |
| **45+ Job Optimizations** | Specialized AI for each job class | ✅ Complete |
| **Element Effectiveness** | Smart targeting based on monster weaknesses | ✅ Complete |
| **Emergency Protocols** | Auto-flee, heal, defensive positioning | ✅ Complete |
| **Skill Combo System** | Chain skills for maximum effectiveness | ✅ Complete |
| **Resource Management** | Intelligent HP/SP management | ✅ Complete |

### Progression System

| Feature | Description | Status |
|---------|-------------|--------|
| **Auto-Leveling** | Autonomous leveling from Novice to Endgame | ✅ Complete |
| **Stat Distribution** | Intelligent stat allocation per build | ✅ Complete |
| **Skill Allocation** | Auto-learn optimal skills for your class | ✅ Complete |
| **Job Advancement** | Automatic job changes at appropriate levels | ✅ Complete |
| **Quest Completion** | Navigate and complete quests autonomously | ✅ Complete |
| **Build Templates** | Pre-defined builds for all job classes | ✅ Complete |

### Social Features

| Feature | Description | Status |
|---------|-------------|--------|
| **Natural Chat** | LLM-powered or template-based conversations | ✅ Complete |
| **Party Coordination** | Healer awareness, tank support, formation | ✅ Complete |
| **Guild Management** | Automated guild activities | ✅ Complete |
| **MVP Hunting** | Collaborative boss hunting with loot sharing | ✅ Complete |
| **Friend Management** | Track and interact with friends | ✅ Complete |
| **Trade Negotiation** | Automated trading with players | ✅ Complete |

### Companion System

| Feature | Description | Status |
|---------|-------------|--------|
| **Pet Management** | Auto-feed, command, and coordinate pet | ✅ Complete |
| **Homunculus AI** | Advanced homunculus control and tactics | ✅ Complete |
| **Mercenary Control** | Strategic mercenary deployment | ✅ Complete |
| **Mount Management** | Auto-mount and dismount as needed | ✅ Complete |

### Economy Features

| Feature | Description | Status |
|---------|-------------|--------|
| **Market Intelligence** | Price tracking and trend analysis | ✅ Complete |
| **Vending Optimization** | Auto-pricing based on market conditions | ✅ Complete |
| **Trading Strategy** | Buy low, sell high arbitrage detection | ✅ Complete |
| **Auto-Buying** | Automated NPC and player shop purchases | ✅ Complete |

### Memory System

| Feature | Description | Status |
|---------|-------------|--------|
| **Working Memory** | Immediate context in RAM (~1000 items) | ✅ Complete |
| **Session Memory** | Recent history in DragonflyDB (24h TTL) | ✅ Complete |
| **Persistent Memory** | Long-term knowledge in SQLite | ✅ Complete |
| **Memory Consolidation** | Automatic memory tier transitions | ✅ Complete |

### Anti-Detection

| Feature | Description | Status |
|---------|-------------|--------|
| **Timing Randomization** | Gaussian noise on action delays | ✅ Complete |
| **Movement Humanization** | Bezier curves, pauses, path deviations | ✅ Complete |
| **Behavior Imperfections** | Intentional suboptimal choices (5-10%) | ✅ Complete |
| **Session Management** | Auto-breaks, max play hours | ✅ Complete |
| **Player Pattern Mimicking** | Learn and mimic human player patterns | ✅ Complete |

---

## 📚 Documentation

### Primary Documentation

- **[Complete Documentation](../docs/GODTIER-RO-AI-DOCUMENTATION.md)** - Comprehensive 50+ page guide covering:
  - System Architecture
  - All 4 Compute Backends
  - Memory System Details
  - API Reference
  - Advanced Topics
  - Performance Benchmarks
  - Development Guide

### Additional Resources

- **[OpenKore Wiki](https://openkore.com/wiki/)** - Base OpenKore documentation
- **[OpenKore Forum](https://forums.openkore.com/)** - Community discussions
- **[Discord Server](https://discord.com/invite/hdAhPM6)** - Real-time help
- **[GitHub Issues](https://github.com/OpenKore/openkore/issues)** - Bug reports

### Configuration Examples

Pre-built configurations in [`data/configs/`](data/configs/):
- `farming.yaml` - Efficient farming setup
- `party.yaml` - Party play configuration
- `pvp.yaml` - PvP/WoE setup
- `stealth.yaml` - Maximum anti-detection

### Build Templates

Character builds in [`data/builds/`](data/builds/):
- Knight, Priest, Wizard builds
- Archer, Swordsman, Mage builds
- Specialized job class builds

---

## 📄 License & Credits

### License

**God-Tier RO AI** is licensed under **GNU General Public License v2.0 (GPLv2)**

You are free to:
- ✅ Use the software for any purpose
- ✅ Modify the source code
- ✅ Distribute the software

You must:
- ⚠️ Distribute source code with modifications
- ⚠️ Keep the same license (GPLv2)
- ⚠️ Include copyright notices

See [LICENSE](../LICENSE) file for full details.

### Credits

#### OpenKore Team
Built on the foundation of [OpenKore](https://github.com/OpenKore/openkore), maintained by a dedicated team of contributors worldwide since 2003.

#### Technologies
- **[Python 3.12+](https://www.python.org/)** - Programming language
- **[ZeroMQ](https://zeromq.org/)** - High-performance IPC
- **[DragonflyDB](https://www.dragonflydb.io/)** - Modern Redis alternative
- **[Pydantic](https://docs.pydantic.dev/)** - Data validation
- **[structlog](https://www.structlog.org/)** - Structured logging
- **[PyTorch](https://pytorch.org/)** - Machine learning framework
- **[ONNX Runtime](https://onnxruntime.ai/)** - ML inference engine

#### LLM Providers
- **[OpenAI](https://openai.com/)** - GPT models
- **[Microsoft Azure](https://azure.microsoft.com/products/ai-services/openai-service)** - Enterprise AI
- **[DeepSeek](https://www.deepseek.com/)** - Cost-effective alternative
- **[Anthropic](https://www.anthropic.com/)** - Claude models

### Project Statistics

```
Total Lines of Code:     77,760 Python
Test Suites:            637 tests (100% pass rate)
Test Coverage:          55.23% (target: 90%)
Supported Jobs:         45+
LLM Providers:          4
Compute Backends:       4
Development Time:       ~500 hours
```

---

## 🎯 What's Next?

### Recommended Learning Path

1. **✅ You are here** - Basic setup complete
2. **📖 Read Full Documentation** - Understand all features
3. **🎮 Try Different Backends** - Test CPU, GPU, and LLM modes
4. **⚙️ Customize Configuration** - Tune for your playstyle
5. **🧪 Run Tests** - Ensure everything works
6. **🚀 Deploy & Play** - Start your adventure!

### Getting Advanced

- **Custom Tactical Roles** - Create specialized combat behaviors
- **Build Templates** - Define custom stat/skill progressions
- **Memory Tuning** - Optimize for your hardware
- **Multi-Bot Coordination** - Run coordinated bot parties

### Contributing

Interested in contributing? See [CONTRIBUTING.md](../CONTRIBUTING.md) for:
- Development setup
- Code style guidelines
- Testing requirements
- Pull request process

---

**🎮 Happy Botting!**

For questions or issues, visit:
- 📖 [Full Documentation](../docs/GODTIER-RO-AI-DOCUMENTATION.md)
- 💬 [Discord Community](https://discord.com/invite/hdAhPM6)
- 🐛 [GitHub Issues](https://github.com/OpenKore/openkore/issues)

---

*Last Updated: 2025-11-28 | Version: 3.0.0*