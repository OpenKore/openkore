# ⚙️ Bridge Configuration Reference

> **Complete configuration guide for OpenKore ↔ AI Sidecar bridge system**

## 📋 Table of Contents

- [Overview](#overview)
- [OpenKore Configuration](#openkore-configuration)
- [AI Sidecar Configuration](#ai-sidecar-configuration)
- [Performance Tuning](#performance-tuning)
- [Environment Variables](#environment-variables)
- [Configuration Examples](#configuration-examples)
- [Troubleshooting](#troubleshooting)

---

## Overview

The bridge system requires configuration on **both** the OpenKore side (Perl) and the AI Sidecar side (Python).

### Configuration Files

| File | Location | Purpose |
|------|----------|---------|
| **AI_Bridge.txt** | `plugins/AI_Bridge/` | OpenKore bridge settings |
| **config.txt** | `control/` | Optional: override bridge settings |
| **.env** | `ai_sidecar/` | AI Sidecar environment config |
| **config.yaml** | `ai_sidecar/` | AI Sidecar detailed config (optional) |

---

## OpenKore Configuration

### Primary Configuration File

**Location**: `plugins/AI_Bridge/AI_Bridge.txt`

This file contains all bridge-specific settings for OpenKore.

#### Complete Configuration Template

```ini
###############################################################################
# AI_Bridge Plugin Configuration
###############################################################################

# -----------------------------------------------------------------------------
# Core Settings
# -----------------------------------------------------------------------------

# Enable/disable the AI Bridge plugin
# 0 = Disabled (use OpenKore's built-in AI)
# 1 = Enabled (use AI Sidecar for decisions)
# Default: 1
AI_Bridge_enabled 1

# ZMQ socket address for connecting to AI Sidecar
# Format: tcp://hostname:port
# Use localhost/127.0.0.1 for local sidecar
# Use 0.0.0.0 to allow connections from any interface
# Default: tcp://127.0.0.1:5555
AI_Bridge_address tcp://127.0.0.1:5555

# Alternative addresses for different setups:
# AI_Bridge_address tcp://0.0.0.0:5555        # Listen on all interfaces
# AI_Bridge_address tcp://192.168.1.100:5555  # Remote AI Sidecar
# AI_Bridge_address ipc:///tmp/openkore.ipc   # Unix socket (Linux/Mac)

# -----------------------------------------------------------------------------
# Timing Settings (milliseconds)
# -----------------------------------------------------------------------------

# Socket timeout for send/receive operations
# Lower values = more responsive but higher CPU usage
# Higher values = lower CPU but potential latency
# Range: 10-1000ms
# Default: 50ms
AI_Bridge_timeout_ms 50

# Recommended values by use case:
# - High-performance CPU mode: 30ms
# - Standard CPU/GPU mode: 50ms
# - LLM mode: 100-500ms
# - Slow network: 200ms+

# Time between reconnection attempts when disconnected
# Lower values = faster recovery but more connection attempts
# Higher values = slower recovery but fewer attempts
# Range: 1000-60000ms
# Default: 5000ms (5 seconds)
AI_Bridge_reconnect_ms 5000

# Heartbeat interval for health monitoring
# 0 = Disable heartbeats
# >0 = Send heartbeat every N milliseconds
# Range: 0, 1000-60000ms
# Default: 5000ms (5 seconds)
AI_Bridge_heartbeat_ms 5000

# Set to 0 to disable (not recommended):
# AI_Bridge_heartbeat_ms 0

# -----------------------------------------------------------------------------
# Debug Settings
# -----------------------------------------------------------------------------

# Enable debug logging to OpenKore console
# 0 = Normal logging (errors and important messages only)
# 1 = Verbose debug output (all operations logged)
# Default: 0
AI_Bridge_debug 0

# Enable when troubleshooting:
# - Connection issues
# - Decision application problems
# - Performance issues
# - Integration bugs

# Log full game state JSON (WARNING: very verbose!)
# 0 = Disabled (recommended)
# 1 = Log complete state JSON to console
# Default: 0
AI_Bridge_log_state 0

# Only enable for:
# - Debugging state extraction issues
# - Verifying data accuracy
# - Development/testing
# CAUTION: Produces massive amounts of output!

###############################################################################
# End of Configuration
###############################################################################
```

---

### Configuration via control/config.txt

You can also set bridge options in your main `control/config.txt` file. These **override** values in `AI_Bridge.txt`.

```ini
# In control/config.txt
AI_Bridge_enabled 1
AI_Bridge_address tcp://127.0.0.1:5555
AI_Bridge_timeout_ms 50
AI_Bridge_debug 0
```

**Priority**: `control/config.txt` > `plugins/AI_Bridge/AI_Bridge.txt` > hardcoded defaults

---

### Configuration Options Reference

#### AI_Bridge_enabled

**Type**: Boolean (0 or 1)  
**Default**: 1  
**Description**: Master switch for the AI Bridge plugin.

**Values**:
- `0` - Plugin disabled, OpenKore uses built-in AI
- `1` - Plugin enabled, use AI Sidecar for decisions

**When to disable**:
- Testing OpenKore's native AI
- AI Sidecar maintenance
- Troubleshooting OpenKore issues
- Server connection problems

**Example**:
```ini
AI_Bridge_enabled 1  # Use AI Sidecar
AI_Bridge_enabled 0  # Use built-in AI
```

---

#### AI_Bridge_address

**Type**: String (ZMQ socket address)  
**Default**: `tcp://127.0.0.1:5555`  
**Description**: ZeroMQ endpoint where AI Sidecar is listening.

**Format**: `protocol://host:port`

**Supported Protocols**:
- `tcp://` - TCP socket (most common)
- `ipc://` - Unix domain socket (Linux/Mac only)

**Common Values**:
```ini
# Local sidecar (most common)
AI_Bridge_address tcp://127.0.0.1:5555

# Remote sidecar on LAN
AI_Bridge_address tcp://192.168.1.100:5555

# Bind to all interfaces (not recommended for security)
AI_Bridge_address tcp://0.0.0.0:5555

# Unix socket (Linux/Mac, faster than TCP)
AI_Bridge_address ipc:///tmp/openkore.ipc
```

**Security Notes**:
- Use `127.0.0.1` (localhost) for local sidecar
- Only use `0.0.0.0` on trusted networks
- Consider firewall rules for remote connections

---

#### AI_Bridge_timeout_ms

**Type**: Integer (milliseconds)  
**Default**: 50  
**Range**: 10-1000  
**Description**: Maximum time to wait for ZMQ send/receive operations.

**Guidelines by Backend**:

| Backend | Recommended Timeout | Reasoning |
|---------|---------------------|-----------|
| CPU | 30-50ms | Fast local processing |
| GPU | 50-100ms | Slightly slower due to GPU queue |
| ML | 100-200ms | Model inference time |
| LLM | 200-1000ms | API latency + processing |

**Tuning Tips**:
- Too low: Frequent timeouts, degraded mode
- Too high: Sluggish response, UI freezes
- Monitor actual decision time in logs
- Set 2-3x typical decision time

**Examples**:
```ini
# Fast CPU backend
AI_Bridge_timeout_ms 30

# Standard setup
AI_Bridge_timeout_ms 50

# LLM backend (OpenAI, Claude)
AI_Bridge_timeout_ms 500

# Slow network / remote sidecar
AI_Bridge_timeout_ms 200
```

---

#### AI_Bridge_reconnect_ms

**Type**: Integer (milliseconds)  
**Default**: 5000  
**Range**: 1000-60000  
**Description**: Interval between reconnection attempts after connection loss.

**Considerations**:
- Shorter interval = faster recovery
- Longer interval = less connection spam
- Balance recovery speed vs system load

**Recommended Values**:
```ini
# Aggressive reconnection (development)
AI_Bridge_reconnect_ms 1000

# Standard (production)
AI_Bridge_reconnect_ms 5000

# Conservative (unstable connection)
AI_Bridge_reconnect_ms 10000
```

---

#### AI_Bridge_heartbeat_ms

**Type**: Integer (milliseconds)  
**Default**: 5000  
**Range**: 0 (disabled), 1000-60000  
**Description**: Frequency of health check messages to AI Sidecar.

**Purpose**:
- Monitor connection health
- Detect silent disconnections
- Track system statistics

**Values**:
```ini
# Disabled (not recommended)
AI_Bridge_heartbeat_ms 0

# Frequent monitoring
AI_Bridge_heartbeat_ms 1000

# Standard monitoring
AI_Bridge_heartbeat_ms 5000

# Infrequent monitoring
AI_Bridge_heartbeat_ms 15000
```

**When to disable** (set to 0):
- Extreme performance requirements
- Bandwidth-constrained connections
- Short-lived testing sessions

---

#### AI_Bridge_debug

**Type**: Boolean (0 or 1)  
**Default**: 0  
**Description**: Enable verbose debug logging to console.

**Output Examples**:

With `AI_Bridge_debug 0` (Normal):
```
[AI_Bridge] Connected to AI Sidecar at tcp://127.0.0.1:5555
[AI_Bridge] Applied 3 actions
```

With `AI_Bridge_debug 1` (Verbose):
```
[AI_Bridge] Connected to AI Sidecar at tcp://127.0.0.1:5555
[AI_Bridge] AI_pre tick 12345 completed in 15.23ms
[AI_Bridge] Included party information with 2 members
[AI_Bridge] Included 3 chat messages in game state
[AI_Bridge] Applying action: move
[AI_Bridge] Applying action: skill
[AI_Bridge] Applying action: chat_send
[AI_Bridge] Applied 3 actions
```

**When to enable**:
- Troubleshooting connection issues
- Debugging action execution
- Verifying feature integration
- Development and testing

**Performance Impact**: Minimal (logging is fast)

---

#### AI_Bridge_log_state

**Type**: Boolean (0 or 1)  
**Default**: 0  
**Description**: Log complete game state JSON to console.

**⚠️ WARNING**: Extremely verbose! Produces 500-2000 lines per AI tick.

**Output Example** (truncated):
```
[AI_Bridge] Built game state: {"character":{"name":"TestChar","job_id":4001,"base_level":99,"job_level":50,"hp":8500,"hp_max":10000,"sp":1200,"sp_max":1500,"position":{"x":150,"y":200},"moving":0,"sitting":0,"attacking":0,"target_id":null,"status_effects":[],"buffs":[{"buff_id":13,"name":"Blessing","expires_at":1701234890,"duration":180}],"weight":1200,"weight_max":2400,"zeny":50000,"str":80,"agi":60,"vit":40,"int":1,"dex":50,"luk":30,"base_exp":450000000,"base_exp_max":500000000,"job_exp":12000000,"job_exp_max":15000000,"stat_points":5,"skill_points":3,"learned_skills":{"SM_BASH":{"level":10,"sp_cost":15},"SM_PROVOKE":{"level":10,"sp_cost":13}}},"actors":[{"id":"1234567890","type":2,"name":"Poring","position":{"x":155,"y":205},"hp":50,"hp_max":60,"moving":0,"attacking":0,"target_id":null,"mob_id":1002}],"inventory":[{"index":0,"item_id":501,"name":"Red Potion","amount":20,"equipped":0,"identified":1,"type":0}],"map":{"name":"prt_fild08","width":400,"height":400},"party":null,"extra":{"chat_messages":[]}}
```

**When to enable**:
- Debugging state extraction bugs
- Verifying specific field values
- Diagnosing data corruption
- Creating test fixtures

**⚠️ Only enable temporarily!** The log output is overwhelming.

---

## AI Sidecar Configuration

### Environment Configuration

**Location**: `ai_sidecar/.env`

This file contains environment variables for the Python AI Sidecar.

#### Complete .env Template

```bash
###############################################################################
# AI Sidecar Environment Configuration
###############################################################################

# -----------------------------------------------------------------------------
# Core Settings
# -----------------------------------------------------------------------------

# Debug mode
# false = Normal operation
# true = Verbose debug output
AI_DEBUG_MODE=false

# Log level
# Options: DEBUG, INFO, WARNING, ERROR, CRITICAL
AI_LOG_LEVEL=INFO

# -----------------------------------------------------------------------------
# ZeroMQ Communication
# -----------------------------------------------------------------------------

# ZeroMQ bind address
# Should match OpenKore's AI_Bridge_address
# Use tcp://127.0.0.1:5555 for local connections
# Use tcp://0.0.0.0:5555 to accept from any interface
AI_ZMQ_BIND_ADDRESS=tcp://127.0.0.1:5555

# Alternative addresses:
# AI_ZMQ_BIND_ADDRESS=tcp://0.0.0.0:5555      # All interfaces
# AI_ZMQ_BIND_ADDRESS=ipc:///tmp/openkore.ipc # Unix socket

# ZeroMQ timeout (milliseconds)
# Should be slightly less than OpenKore's timeout
AI_ZMQ_TIMEOUT_MS=45

# -----------------------------------------------------------------------------
# Compute Backend
# -----------------------------------------------------------------------------

# Backend selection
# Options: cpu, gpu, ml, llm
# cpu = Rule-based decisions (fastest, no API costs)
# gpu = Neural network decisions (requires CUDA)
# ml = Machine learning decisions (requires training)
# llm = Large language model decisions (requires API key)
COMPUTE_BACKEND=cpu

# Fallback chain (comma-separated)
# If primary backend fails, try these in order
COMPUTE_BACKEND_FALLBACK=cpu

# -----------------------------------------------------------------------------
# LLM Configuration (if COMPUTE_BACKEND=llm)
# -----------------------------------------------------------------------------

# LLM Provider
# Options: openai, deepseek, anthropic, azure
LLM_PROVIDER=openai

# API Keys (uncomment and fill as needed)
# OPENAI_API_KEY=sk-proj-xxxxxxxxxxxxxxxxxxxxx
# DEEPSEEK_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxx
# ANTHROPIC_API_KEY=sk-ant-xxxxxxxxxxxxxxxxxxxxx
# AZURE_OPENAI_KEY=xxxxxxxxxxxxxxxxxxxxx
# AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/

# LLM Model
# OpenAI: gpt-4o-mini, gpt-4o, gpt-4-turbo
# DeepSeek: deepseek-chat
# Claude: claude-3-haiku-20240307, claude-3-sonnet-20240229
LLM_MODEL=gpt-4o-mini

# LLM Temperature (0.0-2.0)
# Lower = more deterministic, higher = more creative
LLM_TEMPERATURE=0.7

# Max tokens per response
LLM_MAX_TOKENS=500

# -----------------------------------------------------------------------------
# Decision Engine
# -----------------------------------------------------------------------------

# Decision engine type
# Options: rule_based, ml_based, hybrid
AI_DECISION_ENGINE_TYPE=rule_based

# Decision timeout (milliseconds)
# Maximum time to spend making a decision
AI_DECISION_TIMEOUT_MS=40

# Max actions per decision
# Limit number of actions returned per tick
AI_MAX_ACTIONS_PER_DECISION=5

# -----------------------------------------------------------------------------
# Memory Configuration
# -----------------------------------------------------------------------------

# Memory backend
# Options: redis, dragonflydb, none
MEMORY_BACKEND=dragonflydb

# Redis/DragonflyDB connection
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=

# Memory TTL (seconds)
MEMORY_TTL_HOURS=24

# -----------------------------------------------------------------------------
# Performance Tuning
# -----------------------------------------------------------------------------

# Worker threads
# Number of parallel decision workers
# Recommended: number of CPU cores
AI_WORKER_THREADS=4

# Tick rate (milliseconds)
# How often to process decisions
# Lower = more responsive, higher CPU
AI_TICK_RATE_MS=50

# State cache TTL (milliseconds)
# How long to cache game state
STATE_CACHE_TTL_MS=100

# -----------------------------------------------------------------------------
# Anti-Detection Settings
# -----------------------------------------------------------------------------

# Enable anti-detection features
ANTI_DETECTION_ENABLED=true

# Paranoia level
# Options: low, medium, high, extreme
PARANOIA_LEVEL=medium

# Timing variance (milliseconds)
# Random delay added to actions
TIMING_VARIANCE_MS=200

# Imperfection rate (0.0-1.0)
# Probability of suboptimal decisions
IMPERFECTION_RATE=0.05

# -----------------------------------------------------------------------------
# Logging Configuration
# -----------------------------------------------------------------------------

# Log file path
LOG_FILE_PATH=logs/ai_sidecar.log

# Log rotation
LOG_MAX_SIZE_MB=10
LOG_BACKUP_COUNT=5

# Console logging
LOG_TO_CONSOLE=true

###############################################################################
# End of Configuration
###############################################################################
```

---

### Configuration Presets

#### Development Preset

```bash
# .env for development
AI_DEBUG_MODE=true
AI_LOG_LEVEL=DEBUG
COMPUTE_BACKEND=cpu
AI_ZMQ_BIND_ADDRESS=tcp://127.0.0.1:5555
ANTI_DETECTION_ENABLED=false
LOG_TO_CONSOLE=true
```

#### Production Preset

```bash
# .env for production
AI_DEBUG_MODE=false
AI_LOG_LEVEL=INFO
COMPUTE_BACKEND=cpu
AI_ZMQ_BIND_ADDRESS=tcp://127.0.0.1:5555
ANTI_DETECTION_ENABLED=true
PARANOIA_LEVEL=high
TIMING_VARIANCE_MS=300
LOG_TO_CONSOLE=false
```

#### LLM-Powered Preset

```bash
# .env for LLM backend
AI_DEBUG_MODE=false
AI_LOG_LEVEL=INFO
COMPUTE_BACKEND=llm
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-proj-your-key-here
LLM_MODEL=gpt-4o-mini
AI_ZMQ_TIMEOUT_MS=100
AI_DECISION_TIMEOUT_MS=2000
ANTI_DETECTION_ENABLED=true
```

---

## Performance Tuning

### Low Latency Configuration

**Goal**: Minimize decision time for fast-paced gameplay.

**OpenKore** (`AI_Bridge.txt`):
```ini
AI_Bridge_timeout_ms 30
AI_Bridge_heartbeat_ms 10000
AI_Bridge_debug 0
```

**AI Sidecar** (`.env`):
```bash
COMPUTE_BACKEND=cpu
AI_DECISION_TIMEOUT_MS=25
AI_TICK_RATE_MS=50
AI_WORKER_THREADS=8
STATE_CACHE_TTL_MS=50
```

**Expected Latency**: 10-20ms per decision

---

### High Throughput Configuration

**Goal**: Process maximum actions per second.

**OpenKore** (`AI_Bridge.txt`):
```ini
AI_Bridge_timeout_ms 50
AI_Bridge_debug 0
```

**AI Sidecar** (`.env`):
```bash
COMPUTE_BACKEND=cpu
AI_MAX_ACTIONS_PER_DECISION=10
AI_WORKER_THREADS=16
AI_TICK_RATE_MS=40
```

**Expected Throughput**: 20-30 actions/sec

---

### Resource-Constrained Configuration

**Goal**: Minimize CPU and memory usage.

**OpenKore** (`AI_Bridge.txt`):
```ini
AI_Bridge_timeout_ms 100
AI_Bridge_heartbeat_ms 30000
AI_Bridge_debug 0
AI_Bridge_log_state 0
```

**AI Sidecar** (`.env`):
```bash
COMPUTE_BACKEND=cpu
AI_WORKER_THREADS=2
AI_TICK_RATE_MS=100
STATE_CACHE_TTL_MS=200
MEMORY_BACKEND=none
```

**Resource Usage**: ~50MB RAM, 5-10% CPU

---

### Remote Sidecar Configuration

**Goal**: Run AI Sidecar on different machine.

**AI Sidecar Machine** (`.env`):
```bash
AI_ZMQ_BIND_ADDRESS=tcp://0.0.0.0:5555  # Listen on all interfaces
```

**OpenKore Machine** (`AI_Bridge.txt`):
```ini
AI_Bridge_address tcp://192.168.1.100:5555  # Remote IP
AI_Bridge_timeout_ms 200  # Higher for network latency
AI_Bridge_reconnect_ms 10000
```

**Firewall Rules**:
```bash
# On AI Sidecar machine
sudo ufw allow 5555/tcp
```

---

## Environment Variables

### System Environment Variables

These can be set in shell/system environment instead of `.env`:

```bash
# Linux/Mac
export AI_DEBUG_MODE=true
export OPENAI_API_KEY=sk-proj-xxxxx
export COMPUTE_BACKEND=cpu

# Windows (PowerShell)
$env:AI_DEBUG_MODE = "true"
$env:OPENAI_API_KEY = "sk-proj-xxxxx"
$env:COMPUTE_BACKEND = "cpu"

# Windows (Command Prompt)
set AI_DEBUG_MODE=true
set OPENAI_API_KEY=sk-proj-xxxxx
set COMPUTE_BACKEND=cpu
```

**Priority**: System environment > `.env` file > defaults

---

## Configuration Examples

### Example 1: Local Development

**OpenKore** (`plugins/AI_Bridge/AI_Bridge.txt`):
```ini
AI_Bridge_enabled 1
AI_Bridge_address tcp://127.0.0.1:5555
AI_Bridge_timeout_ms 50
AI_Bridge_debug 1
AI_Bridge_log_state 0
```

**AI Sidecar** (`.env`):
```bash
AI_DEBUG_MODE=true
AI_LOG_LEVEL=DEBUG
COMPUTE_BACKEND=cpu
AI_ZMQ_BIND_ADDRESS=tcp://127.0.0.1:5555
LOG_TO_CONSOLE=true
```

---

### Example 2: Production Server

**OpenKore** (`plugins/AI_Bridge/AI_Bridge.txt`):
```ini
AI_Bridge_enabled 1
AI_Bridge_address tcp://127.0.0.1:5555
AI_Bridge_timeout_ms 50
AI_Bridge_reconnect_ms 5000
AI_Bridge_heartbeat_ms 5000
AI_Bridge_debug 0
AI_Bridge_log_state 0
```

**AI Sidecar** (`.env`):
```bash
AI_DEBUG_MODE=false
AI_LOG_LEVEL=WARNING
COMPUTE_BACKEND=cpu
AI_ZMQ_BIND_ADDRESS=tcp://127.0.0.1:5555
ANTI_DETECTION_ENABLED=true
PARANOIA_LEVEL=high
LOG_TO_CONSOLE=false
LOG_FILE_PATH=logs/ai_sidecar.log
```

---

### Example 3: LLM-Powered Bot

**OpenKore** (`plugins/AI_Bridge/AI_Bridge.txt`):
```ini
AI_Bridge_enabled 1
AI_Bridge_address tcp://127.0.0.1:5555
AI_Bridge_timeout_ms 500
AI_Bridge_debug 0
```

**AI Sidecar** (`.env`):
```bash
AI_DEBUG_MODE=false
AI_LOG_LEVEL=INFO
COMPUTE_BACKEND=llm
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-proj-your-actual-key-here
LLM_MODEL=gpt-4o-mini
LLM_TEMPERATURE=0.7
AI_ZMQ_BIND_ADDRESS=tcp://127.0.0.1:5555
AI_DECISION_TIMEOUT_MS=2000
ANTI_DETECTION_ENABLED=true
```

---

## Troubleshooting

### Configuration Not Loading

**Problem**: Changes to config files not taking effect

**Solutions**:
1. Restart OpenKore completely
2. Check file permissions (must be readable)
3. Verify file location is correct
4. Check for syntax errors in config files

---

### Address Already in Use

**Problem**: 
```
Error: Address already in use: tcp://127.0.0.1:5555
```

**Solutions**:
1. Stop other AI Sidecar instances
2. Change port number in both configs
3. Kill process using port:
   ```bash
   # Linux/Mac
   lsof -ti:5555 | xargs kill -9
   
   # Windows
   netstat -ano | findstr :5555
   taskkill /PID <PID> /F
   ```

---

### Permission Denied

**Problem**: Cannot bind to port or read config

**Solutions**:
```bash
# Fix file permissions
chmod 644 plugins/AI_Bridge/AI_Bridge.txt
chmod 644 ai_sidecar/.env

# Run as admin (Windows) or use sudo (Linux/Mac) if needed
# Or use port > 1024 (no admin required)
AI_Bridge_address tcp://127.0.0.1:5555  # OK
AI_Bridge_address tcp://127.0.0.1:80    # Requires admin
```

---

### Invalid Configuration Value

**Problem**: Config value rejected or ignored

**Solutions**:
1. Check value is in valid range
2. Verify correct data type (number vs string)
3. Remove quotes around numeric values:
   ```ini
   # Wrong
   AI_Bridge_timeout_ms "50"
   
   # Correct
   AI_Bridge_timeout_ms 50
   ```

---

## Next Steps

- 📖 [Integration Guide](AI_SIDECAR_BRIDGE_GUIDE.md) - System architecture
- 🧪 [Testing Guide](BRIDGE_TESTING_GUIDE.md) - Validation procedures
- 📋 [Action Types Reference](ACTION_TYPES_REFERENCE.md) - Available actions

---

**Last Updated**: December 5, 2025  
**Version**: 1.0.0  
**Configurations Documented**: All available options