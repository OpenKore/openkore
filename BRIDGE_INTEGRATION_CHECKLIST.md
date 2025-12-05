# 📋 Bridge Integration Checklist

> **Comprehensive pre-deployment and validation checklist for OpenKore-AI bridge system**

**Version:** 1.0.0  
**Last Updated:** December 5, 2025  
**Status:** Production Ready

---

## 📑 Table of Contents

- [Quick Start](#-quick-start)
- [Pre-Deployment](#-pre-deployment-checklist)
- [Configuration](#-configuration-validation)
- [Bridge Activation](#-bridge-activation-verification)
- [Subsystem Testing](#-subsystem-functionality-tests)
- [Performance](#-performance-validation)
- [Error Handling](#-error-handling-tests)
- [Production Readiness](#-production-readiness-criteria)

---

## 🚀 Quick Start

**Before you begin, ensure you have:**
- ✅ Completed basic installation
- ✅ Read [GODTIER-RO-AI-DOCUMENTATION.md](docs/GODTIER-RO-AI-DOCUMENTATION.md)
- ✅ Run validation scripts successfully

**Estimated Time:** 30-45 minutes for complete checklist

---

## 🔧 Pre-Deployment Checklist

### Infrastructure Requirements

#### System Resources
- [ ] **CPU:** 2+ cores available (4+ recommended)
- [ ] **RAM:** 2GB minimum free (4GB+ recommended)
- [ ] **Storage:** 1GB free space (10GB+ for GPU mode)
- [ ] **Network:** Stable localhost connectivity

#### Software Dependencies
- [ ] **Perl 5.x** installed and in PATH
- [ ] **Python 3.9+** installed (3.12+ optimal)
- [ ] **Git** installed (for updates)
- [ ] **ZeroMQ library** available

#### Perl Modules
- [ ] `ZMQ::FFI` installed
  ```bash
  perl -MZMQ::FFI -e 'print "OK\n"'
  ```
- [ ] `JSON::XS` installed (or JSON::PP fallback)
  ```bash
  perl -MJSON::XS -e 'print "OK\n"'
  ```
- [ ] `Time::HiRes` installed
  ```bash
  perl -MTime::HiRes -e 'print "OK\n"'
  ```

#### Python Packages
- [ ] **Virtual environment** created
  ```bash
  cd ai_sidecar && python3 -m venv .venv
  ```
- [ ] **Dependencies** installed
  ```bash
  source .venv/bin/activate && pip install -r requirements.txt
  ```
- [ ] **Core packages** verified:
  - [ ] pyzmq >= 25.1.0
  - [ ] pydantic >= 2.5.0
  - [ ] pydantic-settings >= 2.1.0
  - [ ] structlog >= 23.2.0

### Optional Components

#### DragonflyDB / Redis (Session Memory)
- [ ] DragonflyDB installed or Docker available
- [ ] Service running on port 6379
- [ ] Connection test passes:
  ```bash
  redis-cli -h localhost -p 6379 ping
  ```

#### GPU Support (Optional)
- [ ] NVIDIA GPU with CUDA support
- [ ] CUDA Toolkit installed (12.x+)
- [ ] ONNX Runtime GPU installed
- [ ] GPU detection test passes:
  ```bash
  nvidia-smi
  ```

#### LLM API Access (Optional)
- [ ] API provider selected (OpenAI, Azure, DeepSeek, or Claude)
- [ ] API key obtained and secured
- [ ] Account has sufficient credits/quota
- [ ] API connectivity tested

---

## ⚙️ Configuration Validation

### AI Sidecar Configuration

#### Environment File
- [ ] `.env` file created from `.env.example`
- [ ] Core settings configured:
  ```bash
  # Required
  AI_DEBUG_MODE=false
  AI_LOG_LEVEL=INFO
  AI_ZMQ_BIND_ADDRESS=tcp://127.0.0.1:5555
  AI_DECISION_ENGINE_TYPE=rule_based  # or stub, ml, llm
  ```

#### Backend Configuration
- [ ] Compute backend selected:
  - [ ] CPU mode (default, no config needed)
  - [ ] GPU mode (requires CUDA setup)
  - [ ] LLM mode (requires API keys)
  - [ ] ML mode (requires trained models)

#### LLM Configuration (if using LLM mode)
- [ ] Provider credentials set:
  ```bash
  # OpenAI
  OPENAI_API_KEY=sk-...
  OPENAI_MODEL=gpt-4o-mini
  
  # OR Azure
  AZURE_OPENAI_KEY=...
  AZURE_OPENAI_ENDPOINT=https://...
  
  # OR DeepSeek
  DEEPSEEK_API_KEY=sk-...
  
  # OR Anthropic
  ANTHROPIC_API_KEY=sk-ant-...
  ```
- [ ] Rate limits configured appropriately
- [ ] Cost budget set (if applicable)

#### Memory Configuration
- [ ] Working memory settings verified
- [ ] Session memory backend selected
- [ ] Persistent memory database path set
- [ ] Cleanup intervals configured

### OpenKore Configuration

#### Plugin Files
- [ ] `AI_Bridge.pl` present in `plugins/`
- [ ] `godtier_chat_bridge.pl` present (optional, for chat)
- [ ] Plugin syntax validation passed:
  ```bash
  perl -c plugins/AI_Bridge.pl
  perl -c plugins/godtier_chat_bridge.pl
  ```

#### Plugin Configuration
- [ ] `plugins/AI_Bridge.txt` configured (if exists)
- [ ] Debug mode set appropriately
- [ ] ZeroMQ endpoint matches AI Sidecar
- [ ] Timeout values reasonable

#### Server Configuration
- [ ] `control/config.txt` configured for target server
- [ ] Character credentials set
- [ ] Server address and port correct
- [ ] Game version matches server

---

## 🔌 Bridge Activation Verification

### Initial Startup

#### Step 1: Start AI Sidecar
- [ ] Terminal 1 opened
- [ ] Virtual environment activated
- [ ] AI Sidecar started:
  ```bash
  cd ai_sidecar
  source .venv/bin/activate
  python main.py
  ```
- [ ] Startup message displayed:
  ```
  ✅ AI Sidecar ready! Listening on: tcp://127.0.0.1:5555
  ```
- [ ] No error messages in log

#### Step 2: Start OpenKore
- [ ] Terminal 2 opened
- [ ] OpenKore started:
  ```bash
  ./start.pl  # or start.exe on Windows
  ```
- [ ] Bridge plugin loaded:
  ```
  [GodTier] AI Bridge plugin loaded
  ```
- [ ] Connection established:
  ```
  [GodTier] Connected to AI sidecar at tcp://127.0.0.1:5555
  ```

#### Step 3: Connection Verification
- [ ] No connection errors in either terminal
- [ ] State updates being sent (check AI Sidecar logs)
- [ ] Decisions being received (check OpenKore logs)
- [ ] Bot responding to game events

### Connectivity Tests

#### Run Validation Script
- [ ] Execute: `./validate_bridges.sh` (Linux/Mac) or `validate_bridges.bat` (Windows)
- [ ] All critical checks passed
- [ ] Warnings reviewed and addressed (if any)
- [ ] Exit code 0 (success)

#### Run Bridge Connection Tester
- [ ] Execute: `python ai_sidecar/test_bridge_connection.py`
- [ ] All 5 tests passed:
  - [ ] Basic Connectivity
  - [ ] Protocol Validation
  - [ ] Action Generation
  - [ ] Performance Test
  - [ ] Error Handling
- [ ] Average latency acceptable (<50ms for CPU mode)

---

## 🧪 Subsystem Functionality Tests

### P0: Critical Bridges

#### Character Stats
- [ ] Stats extracted correctly:
  - [ ] STR, AGI, VIT, INT, DEX, LUK values accurate
  - [ ] Values update on stat increase
  - [ ] Base/Job levels correct

#### Experience Tracking
- [ ] Base experience visible in AI
- [ ] Job experience visible in AI
- [ ] Max values correct
- [ ] Experience gains detected after kills

#### Stat Allocation
- [ ] AI detects available stat points
- [ ] AI can allocate STR
- [ ] AI can allocate other stats (AGI, VIT, etc.)
- [ ] Stat points decrease correctly after allocation

#### Skill System
- [ ] Learned skills extracted
- [ ] Skill levels correct
- [ ] SP costs accurate
- [ ] AI can allocate skill points
- [ ] New skills detected when learned

### P1: Important Bridges

#### Party Coordination
- [ ] Party members visible
- [ ] Member HP/SP tracked
- [ ] Member positions tracked
- [ ] Party heal actions work (if healer)
- [ ] Party buff actions work (if support)

#### Guild Information
- [ ] Guild name extracted
- [ ] Guild level correct
- [ ] Member count accurate
- [ ] Guild experience tracked

#### Status Effects
- [ ] Buffs detected when applied
- [ ] Buff durations tracked
- [ ] Buff expiration detected
- [ ] Debuffs/ailments detected
- [ ] Positive vs negative classification correct

#### Chat Integration
- [ ] Chat messages captured
- [ ] Sender name correct
- [ ] Message content accurate
- [ ] Channel detection working (public, party, guild, PM)
- [ ] AI can send chat responses (if configured)

### P2: Advanced Bridges

#### Pet Management
- [ ] Pet state tracked (if you have pet)
- [ ] Intimacy level visible
- [ ] Hunger tracked
- [ ] Feed action works

#### Homunculus Control
- [ ] Homunculus stats tracked (if Alchemist)
- [ ] HP/SP values correct
- [ ] Skills visible
- [ ] Homunculus actions work

#### Equipment System
- [ ] Equipped items detected
- [ ] Item names correct
- [ ] Slot mapping accurate
- [ ] Equip/unequip actions work

#### Companion Systems
- [ ] Mercenary state tracked (if hired)
- [ ] Mount status detected
- [ ] Cart presence tracked (if merchant)

### P3: Optional Bridges

#### NPC Interaction
- [ ] NPC dialogue detected
- [ ] Dialogue choices extracted
- [ ] NPC actions work (talk, choose, close)

#### Quest Tracking
- [ ] Active quests visible
- [ ] Quest objectives tracked
- [ ] Completion status accurate

#### Economy Features
- [ ] Vendor detection works
- [ ] Item prices extracted
- [ ] Buy/sell actions work
- [ ] Market intelligence (if enabled)

#### Environment Awareness
- [ ] Day/night status detected
- [ ] Weather tracking works
- [ ] Ground items visible
- [ ] Pick item action works

---

## 📊 Performance Validation

### Latency Benchmarks

#### Decision Processing Time
- [ ] CPU mode: Average < 20ms
- [ ] GPU mode: Average < 30ms
- [ ] LLM mode: Average < 3000ms (3 seconds)
- [ ] No timeouts under normal operation

#### Memory Usage
- [ ] AI Sidecar RAM: < 1GB (CPU mode)
- [ ] AI Sidecar RAM: < 4GB (GPU mode)
- [ ] No memory leaks over 1 hour test
- [ ] Memory usage stable

#### CPU Usage
- [ ] AI Sidecar: < 25% average (CPU mode)
- [ ] AI Sidecar: < 15% average (GPU mode)
- [ ] OpenKore: < 15% average
- [ ] No CPU spikes causing lag

### Throughput Testing

#### State Update Rate
- [ ] 10+ state updates per second
- [ ] No dropped messages
- [ ] ZeroMQ queue not backing up

#### Action Execution
- [ ] Actions execute within 100ms of decision
- [ ] No action queue overflow
- [ ] Priority actions execute first

### Stress Testing

#### Extended Operation (1 Hour Test)
- [ ] Bot runs continuously for 1+ hours
- [ ] No crashes or disconnections
- [ ] Performance remains stable
- [ ] Resource usage doesn't grow

#### Multiple Characters (if applicable)
- [ ] Multiple bots can connect to single AI Sidecar
- [ ] Each bot receives correct decisions
- [ ] No cross-contamination of state
- [ ] Performance scales reasonably

---

## 🛡️ Error Handling Tests

### Connection Failures

#### AI Sidecar Crash Recovery
- [ ] OpenKore detects AI disconnect
- [ ] Fallback mode activates (if configured)
- [ ] Bot doesn't crash
- [ ] Reconnection works after AI restart

#### OpenKore Crash Recovery
- [ ] AI Sidecar handles disconnection gracefully
- [ ] No memory leaks when client disconnects
- [ ] Accepts new connections after restart

#### Network Interruption
- [ ] Timeout errors logged clearly
- [ ] Recovery happens automatically
- [ ] No data corruption

### Invalid Data Handling

#### Malformed Messages
- [ ] AI rejects invalid JSON
- [ ] Error logged with details
- [ ] System continues operating

#### Missing Required Fields
- [ ] Validation catches missing data
- [ ] Helpful error message shown
- [ ] Graceful degradation if possible

#### Out-of-Range Values
- [ ] Bounds checking works
- [ ] Invalid values rejected or clamped
- [ ] Warning logged

### Resource Exhaustion

#### Memory Pressure
- [ ] AI handles low memory gracefully
- [ ] Cache eviction works
- [ ] No out-of-memory crashes

#### Disk Full
- [ ] Logging handles disk full
- [ ] Warning message shown
- [ ] Critical operations continue

---

## 🚀 Production Readiness Criteria

### Stability Requirements

#### Uptime
- [ ] 24-hour stress test completed successfully
- [ ] No crashes or hangs
- [ ] Automatic recovery from errors
- [ ] Acceptable mean time between failures (MTBF > 100 hours)

#### Data Integrity
- [ ] State updates are accurate
- [ ] No data corruption detected
- [ ] Decisions are consistent
- [ ] Memory persists correctly (if enabled)

### Security Considerations

#### API Key Management
- [ ] API keys stored in `.env` (not in code)
- [ ] `.env` file in `.gitignore`
- [ ] File permissions restricted (600 on Linux)
- [ ] No keys in logs

#### Network Security
- [ ] ZeroMQ binds to localhost only
- [ ] No external connections accepted
- [ ] Firewall rules appropriate

#### Anti-Detection (if relevant)
- [ ] Timing randomization enabled
- [ ] Movement humanization configured
- [ ] Session limits set
- [ ] Imperfection rate configured

### Monitoring & Logging

#### Log Configuration
- [ ] Appropriate log level set (INFO or WARNING for production)
- [ ] Log rotation configured
- [ ] Disk space monitored
- [ ] Error alerts set up (if applicable)

#### Health Monitoring
- [ ] Health check endpoint working (if available)
- [ ] Resource usage monitored
- [ ] Performance metrics tracked
- [ ] Alerting configured for failures

### Documentation

#### Operational Docs
- [ ] Setup instructions documented
- [ ] Configuration options explained
- [ ] Troubleshooting guide available
- [ ] Recovery procedures documented

#### Runbooks
- [ ] Start/stop procedures documented
- [ ] Backup procedures defined
- [ ] Upgrade procedures tested
- [ ] Rollback plan exists

---

## ✅ Final Verification

### Deployment Sign-Off

Before deploying to production, verify:

- [ ] All critical (P0) tests passed
- [ ] All important (P1) tests passed
- [ ] Performance meets requirements
- [ ] Error handling tested
- [ ] Security measures in place
- [ ] Monitoring configured
- [ ] Documentation complete
- [ ] Team trained (if applicable)

### Success Criteria

**The bridge is production-ready when:**

✅ All validation scripts pass  
✅ Bridge connection test passes  
✅ P0 and P1 subsystems working  
✅ Performance within acceptable limits  
✅ Error handling robust  
✅ 24-hour stability test passed  
✅ Documentation complete  
✅ Monitoring in place

---

## 📚 Additional Resources

### Documentation
- **[Complete Documentation](docs/GODTIER-RO-AI-DOCUMENTATION.md)** - Full system guide
- **[Testing Guide](docs/BRIDGE_TESTING_GUIDE.md)** - Detailed test procedures
- **[Troubleshooting](BRIDGE_TROUBLESHOOTING.md)** - Common issues and solutions

### Tools
- **Validation Scripts**
  - Linux/Mac: `./validate_bridges.sh`
  - Windows: `validate_bridges.bat`
- **Connection Tester**
  - `python ai_sidecar/test_bridge_connection.py`

### Support
- **Discord:** [OpenKore Community](https://discord.com/invite/hdAhPM6)
- **Forum:** [OpenKore Forums](https://forums.openkore.com/)
- **Issues:** [GitHub Issues](https://github.com/OpenKore/openkore/issues)

---

## 📝 Checklist Progress Tracking

Use this section to track your progress:

```
Pre-Deployment:     [ ] Not Started  [ ] In Progress  [ ] Complete
Configuration:      [ ] Not Started  [ ] In Progress  [ ] Complete
Bridge Activation:  [ ] Not Started  [ ] In Progress  [ ] Complete
Subsystem Tests:    [ ] Not Started  [ ] In Progress  [ ] Complete
Performance:        [ ] Not Started  [ ] In Progress  [ ] Complete
Error Handling:     [ ] Not Started  [ ] In Progress  [ ] Complete
Production Ready:   [ ] Not Started  [ ] In Progress  [ ] Complete
```

**Deployment Date:** _______________  
**Deployed By:** _______________  
**Sign-Off:** _______________

---

**Version:** 1.0.0  
**Last Updated:** December 5, 2025  
**Maintainer:** OpenKore-AI Team