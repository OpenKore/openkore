# 🔧 Bridge Troubleshooting Quick Reference

> **Quick solutions for common OpenKore-AI bridge issues**

**Version:** 1.0.0  
**Last Updated:** December 5, 2025

---

## 📑 Table of Contents

- [Quick Diagnostics](#-quick-diagnostics)
- [Connection Issues](#-connection-issues)
- [State Transfer Problems](#-state-transfer-problems)
- [Action Execution Issues](#-action-execution-issues)
- [Performance Problems](#-performance-problems)
- [Memory Issues](#-memory-issues)
- [LLM-Specific Issues](#-llm-specific-issues)
- [Chat Bridge Issues](#-chat-bridge-issues)
- [Platform-Specific Issues](#-platform-specific-issues)

---

## 🔍 Quick Diagnostics

### First Steps for Any Issue

1. **Check both logs:**
   - AI Sidecar terminal (Python)
   - OpenKore console (Perl)

2. **Run validation scripts:**
   ```bash
   # Linux/Mac
   ./validate_bridges.sh
   
   # Windows
   validate_bridges.bat
   ```

3. **Test connection:**
   ```bash
   python ai_sidecar/test_bridge_connection.py
   ```

4. **Enable debug mode:**
   ```bash
   export AI_DEBUG_MODE=true
   export AI_LOG_LEVEL=DEBUG
   ```

---

## 🔌 Connection Issues

### ❌ "AI not responding"

**Symptoms:**
```
[AI_Bridge] Failed to connect to AI sidecar
[AI_Bridge] Communication timeout
```

**Likely Causes:**
1. AI Sidecar not running
2. Wrong endpoint configuration
3. Firewall blocking connection
4. Port already in use

**Solutions:**

#### Step 1: Verify AI Sidecar is Running
```bash
# Check if process exists
ps aux | grep python | grep main.py

# Or check port
netstat -tuln | grep 5555  # Linux
netstat -ano | findstr :5555  # Windows
```

**Fix:** Start AI Sidecar if not running:
```bash
cd ai_sidecar
source .venv/bin/activate
python main.py
```

#### Step 2: Verify Endpoint Configuration
```bash
# Check AI Sidecar endpoint
grep ZMQ ai_sidecar/.env
# Should show: AI_ZMQ_BIND_ADDRESS=tcp://127.0.0.1:5555

# Check OpenKore plugin config (if exists)
grep address plugins/AI_Bridge.txt
```

**Fix:** Ensure both use same endpoint:
```bash
# In ai_sidecar/.env
AI_ZMQ_BIND_ADDRESS=tcp://127.0.0.1:5555

# In plugins/AI_Bridge.txt (if exists)
AI_Bridge_address tcp://127.0.0.1:5555
```

#### Step 3: Check Firewall
```bash
# Linux - allow port
sudo ufw allow 5555/tcp

# macOS - check firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

# Windows - PowerShell as admin
New-NetFirewallRule -DisplayName "OpenKore AI" -Direction Inbound -LocalPort 5555 -Protocol TCP -Action Allow
```

#### Step 4: Try Alternative Endpoint
```bash
# Bind to all interfaces instead of just localhost
AI_ZMQ_BIND_ADDRESS=tcp://0.0.0.0:5555

# Or use different port
AI_ZMQ_BIND_ADDRESS=tcp://127.0.0.1:5556
```

**Verification:**
```bash
# Run connection test
python ai_sidecar/test_bridge_connection.py

# Expected: All tests pass
```

---

### ❌ "Connection refused"

**Symptoms:**
```
ConnectionRefusedError: [Errno 111] Connection refused
zmq.error.ZMQError: Connection refused
```

**Solutions:**

1. **Start AI Sidecar first, then OpenKore**
   ```bash
   # Terminal 1
   cd ai_sidecar && python main.py
   
   # Wait for "AI Sidecar ready!"
   # Then in Terminal 2
   ./start.pl
   ```

2. **Check if another service is using port 5555**
   ```bash
   # Find what's using the port
   lsof -i :5555  # Linux/Mac
   netstat -ano | findstr :5555  # Windows
   
   # Kill the process or use different port
   ```

3. **Verify localhost is working**
   ```bash
   ping 127.0.0.1
   
   # If fails, check /etc/hosts
   # Should contain: 127.0.0.1 localhost
   ```

---

### ❌ "ZMQ timeout errors"

**Symptoms:**
```
[AI_Bridge] Request timeout after 100ms
zmq.Again: Resource temporarily unavailable
```

**Solutions:**

1. **Increase timeout values**
   ```bash
   # In ai_sidecar/.env
   AI_ZMQ_RECV_TIMEOUT_MS=500
   AI_ZMQ_SEND_TIMEOUT_MS=500
   
   # In OpenKore plugin config
   AI_Bridge_timeout_ms 500
   ```

2. **Check AI Sidecar performance**
   ```bash
   # Monitor CPU usage
   top | grep python
   
   # If high CPU, reduce decision complexity
   ```

3. **Use faster decision engine**
   ```bash
   # Switch from LLM to CPU mode temporarily
   AI_DECISION_ENGINE_TYPE=rule_based
   ```

---

## 📊 State Transfer Problems

### ❌ "Missing data in state"

**Symptoms:**
- AI logs show incomplete character data
- Stats are 0 or null
- Actions not generated

**Solutions:**

1. **Verify character is logged in**
   ```perl
   # In OpenKore console
   call print("Char name: " . ($char->{name} || "NOT LOGGED IN") . "\n")
   ```

2. **Enable state logging**
   ```bash
   # In OpenKore console
   call $config{AI_Bridge_log_state} = 1
   
   # Wait one tick, then check console for state JSON
   # Disable after: call $config{AI_Bridge_log_state} = 0
   ```

3. **Check for plugin conflicts**
   ```bash
   # Temporarily disable other plugins
   # Reload AI_Bridge.pl only
   ```

**Verification:**
```bash
# AI Sidecar logs should show complete character data
grep "character" ai_sidecar_log.txt
```

---

### ❌ "JSON decode errors"

**Symptoms:**
```
[AI_Bridge] Failed to decode JSON: malformed input
JSONDecodeError: Expecting value: line 1 column 1
```

**Solutions:**

1. **Update JSON module**
   ```bash
   cpanm JSON::XS --force
   
   # Or use CPAN
   cpan install JSON::XS
   ```

2. **Check for special characters**
   - Character names with special symbols
   - Chat messages with emoji or Unicode
   - Item names with unusual characters

3. **Verify message format**
   ```perl
   # In AI_Bridge.pl, add debug logging
   # Check that JSON is valid before sending
   ```

**Verification:**
```bash
# Test with simple state
python ai_sidecar/test_bridge_connection.py --verbose
```

---

## 🎮 Action Execution Issues

### ❌ "Actions not executing"

**Symptoms:**
- AI generates decisions
- OpenKore receives actions
- Nothing happens in game

**Solutions:**

1. **Check action type support**
   ```bash
   # Review docs/ACTION_TYPES_REFERENCE.md
   # Ensure action type is implemented
   ```

2. **Verify action parameters**
   ```python
   # Example valid action:
   {
       "type": "attack",
       "target": 10001,  # Must be valid actor ID
       "priority": 5
   }
   ```

3. **Check OpenKore AI state**
   ```perl
   # In OpenKore console
   call print("AI: " . AI::state() . "\n")
   
   # Should be "auto" not "manual" or "off"
   ai auto  # Enable AI if needed
   ```

4. **Review apply_single_action() implementation**
   - Check plugins/AI_Bridge.pl
   - Ensure all action types handled
   - Verify command execution

**Verification:**
```bash
# Enable debug in OpenKore console
call $config{AI_Bridge_debug} = 1

# Watch for action application logs
```

---

### ❌ "Skill actions fail"

**Symptoms:**
- Skill actions generated
- Skills not used in game

**Solutions:**

1. **Verify skill is learned**
   ```perl
   # Check character skills
   call my $sk = $char->{skills}; foreach (keys %$sk) { print "$_: " . $sk->{$_}{lv} . "\n" }
   ```

2. **Check SP availability**
   ```perl
   call print("SP: " . $char->{sp} . "/" . $char->{sp_max} . "\n")
   ```

3. **Verify skill ID mapping**
   - Check if skill ID is correct for server
   - Some servers use different skill IDs

4. **Check skill requirements**
   - Target in range
   - Valid target type
   - No skill cooldown active

---

### ❌ "Movement actions ignored"

**Symptoms:**
- Move actions generated
- Character doesn't move

**Solutions:**

1. **Check if character is stuck**
   ```perl
   call print("Pos: " . $char->{pos}{x} . "," . $char->{pos}{y} . "\n")
   call print("Moving: " . ($char->{moving} ? "Yes" : "No") . "\n")
   ```

2. **Verify target coordinates are valid**
   - Within map bounds
   - Not in unwalkable terrain
   - Path exists to target

3. **Check if character is sitting**
   ```perl
   call print("Sitting: " . ($char->{sitting} ? "Yes" : "No") . "\n")
   
   # Stand up if needed
   call Commands::run("stand")
   ```

---

## ⚡ Performance Problems

### ⚠️ "High latency / Slow decisions"

**Symptoms:**
- Decisions take >100ms (CPU mode)
- Bot feels sluggish
- Timeouts occurring

**Causes & Solutions:**

#### Cause 1: LLM Mode Too Slow
```bash
# Switch to CPU mode
AI_DECISION_ENGINE_TYPE=rule_based

# Or use faster LLM model
OPENAI_MODEL=gpt-4o-mini  # Instead of gpt-4
```

#### Cause 2: Too Many Features Enabled
```yaml
# config.yaml - Disable expensive features
behaviors:
  adaptive:
    enabled: false
  consciousness:
    enabled: false
  learning:
    enabled: false
```

#### Cause 3: Slow Memory Backend
```yaml
# Use in-memory session storage instead of Redis
memory:
  session:
    backend: file  # Or none
```

#### Cause 4: High Tick Rate
```yaml
# Reduce tick frequency
ipc:
  tick_interval_ms: 300  # Slower (was 200)
```

**Verification:**
```bash
# Monitor decision latency
grep "processing_time_ms" ai_sidecar_log.txt

# Should average <20ms for CPU, <30ms for GPU
```

---

### ⚠️ "High CPU usage"

**Symptoms:**
- CPU constantly at 80-100%
- System becomes slow
- Fan noise increases

**Solutions:**

1. **Reduce tick rate**
   ```yaml
   general:
     tick_rate_ms: 500  # Much slower, less CPU
   ```

2. **Use simpler decision engine**
   ```bash
   AI_DECISION_ENGINE_TYPE=stub  # Minimal processing
   ```

3. **Disable background processes**
   ```yaml
   behaviors:
     all_optional_features:
       enabled: false
   ```

4. **Check for infinite loops**
   ```bash
   # Profile the code
   python -m cProfile main.py > profile.txt
   ```

---

### ⚠️ "Memory leak / Growing RAM"

**Symptoms:**
- RAM usage grows over time
- Eventually runs out of memory
- System swap usage increases

**Solutions:**

1. **Enable aggressive cleanup**
   ```yaml
   memory:
     working:
       max_entries: 500      # Reduce buffer
       cleanup_interval_s: 60  # Clean more often
   ```

2. **Reduce session TTL**
   ```yaml
   memory:
     session:
       ttl_hours: 6  # Shorter retention (was 24)
   ```

3. **Disable memory features**
   ```yaml
   memory:
     working:
       enabled: false
     session:
       backend: none
   ```

4. **Monitor memory over time**
   ```bash
   # Track memory usage
   watch -n 5 'ps aux | grep python'
   ```

**Verification:**
```bash
# Run for 2 hours, check if memory stabilizes
# Use htop or Task Manager
```

---

## 💾 Memory Issues

### ❌ "DragonflyDB connection failed"

**Symptoms:**
```
ConnectionRefusedError: Could not connect to DragonflyDB at localhost:6379
redis.exceptions.ConnectionError
```

**Solutions:**

1. **Start DragonflyDB**
   ```bash
   # Using Docker
   docker run -d --name dragonfly -p 6379:6379 \
     docker.dragonflydb.io/dragonflydb/dragonfly
   
   # Verify
   docker ps | grep dragonfly
   ```

2. **Test connection**
   ```bash
   redis-cli -h localhost -p 6379 ping
   # Expected: PONG
   ```

3. **Use Redis instead**
   ```bash
   # Install Redis
   sudo apt-get install redis-server
   
   # Start
   sudo systemctl start redis
   
   # Or with Docker
   docker run -d --name redis -p 6379:6379 redis:alpine
   ```

4. **Disable session memory**
   ```yaml
   # config.yaml - Use file-based session storage
   memory:
     session:
       backend: file
       file_path: ./data/session.json
   
   # Or disable completely
   memory:
     session:
       backend: none
   ```

**Verification:**
```bash
# Check service is running
redis-cli ping

# Check AI can connect
python -c "import redis; r=redis.Redis(); print(r.ping())"
```

---

### ❌ "SQLite database errors"

**Symptoms:**
```
sqlite3.OperationalError: unable to open database file
sqlite3.DatabaseError: database disk image is malformed
```

**Solutions:**

1. **Check file permissions**
   ```bash
   # Ensure directory is writable
   chmod 755 ai_sidecar/data/
   touch ai_sidecar/data/test.db
   rm ai_sidecar/data/test.db
   ```

2. **Fix corrupted database**
   ```bash
   # Backup old database
   mv ai_sidecar/data/memory.db ai_sidecar/data/memory.db.backup
   
   # Start fresh (will recreate)
   python main.py
   ```

3. **Use different path**
   ```yaml
   memory:
     persistent:
       db_path: /tmp/openkore_memory.db
   ```

---

## 🤖 LLM-Specific Issues

### ❌ "LLM API timeout"

**Symptoms:**
```
TimeoutError: LLM API request timed out after 10 seconds
openai.APITimeoutError
```

**Solutions:**

1. **Increase timeout**
   ```yaml
   llm:
     timeout_seconds: 30  # Increase from 10
   ```

2. **Use faster model**
   ```bash
   # OpenAI
   OPENAI_MODEL=gpt-4o-mini  # Fast, cheap
   
   # DeepSeek
   DEEPSEEK_MODEL=deepseek-chat  # Very fast
   
   # Claude
   ANTHROPIC_MODEL=claude-3-haiku  # Fast Claude
   ```

3. **Enable fallback**
   ```yaml
   backend:
     primary: llm
     fallback_chain: [cpu]  # Auto-switch if LLM fails
   ```

4. **Reduce context size**
   ```yaml
   llm:
     max_tokens: 500  # Reduce from 2000
     context_window: 2048  # Smaller context
   ```

---

### ❌ "LLM API rate limit"

**Symptoms:**
```
openai.RateLimitError: Rate limit exceeded
Too many requests (429)
```

**Solutions:**

1. **Configure rate limiting**
   ```yaml
   llm:
     rate_limits:
       requests_per_minute: 20  # Reduce from 60
       concurrent_requests: 2
   ```

2. **Enable caching**
   ```yaml
   llm:
     cache:
       enabled: true
       ttl_seconds: 600  # 10 min cache
   ```

3. **Use cheaper model temporarily**
   ```bash
   # Switch to GPT-3.5 turbo
   OPENAI_MODEL=gpt-3.5-turbo
   ```

4. **Check account status**
   - Verify billing is active
   - Check remaining quota
   - Review usage on provider dashboard

---

### ❌ "LLM API key invalid"

**Symptoms:**
```
openai.AuthenticationError: Invalid API key
401 Unauthorized
```

**Solutions:**

1. **Verify API key format**
   ```bash
   # OpenAI keys start with: sk-proj-
   # Azure keys are alphanumeric
   # DeepSeek keys start with: sk-
   # Claude keys start with: sk-ant-
   
   # Check .env file
   grep API_KEY ai_sidecar/.env
   ```

2. **Regenerate API key**
   - Log into provider dashboard
   - Revoke old key
   - Create new key
   - Update .env file

3. **Check environment loading**
   ```python
   # Test key is loaded
   python -c "from dotenv import load_dotenv; load_dotenv(); import os; print('Key loaded' if os.getenv('OPENAI_API_KEY') else 'Key missing')"
   ```

---

### ❌ "High LLM costs"

**Symptoms:**
- Unexpectedly high API bills
- Budget exceeded quickly

**Solutions:**

1. **Set daily budget**
   ```yaml
   llm:
     rate_limits:
       daily_budget_usd: 5.00  # Hard stop at $5/day
   ```

2. **Switch to cheaper provider**
   ```bash
   # DeepSeek is 10x cheaper than OpenAI
   LLM_PROVIDER=deepseek
   DEEPSEEK_API_KEY=your-key
   ```

3. **Reduce LLM usage**
   ```yaml
   # Only use LLM for chat, not decisions
   behaviors:
     social:
       mode: llm
   decision:
     engine_type: rule_based  # CPU for decisions
   ```

4. **Enable aggressive caching**
   ```yaml
   llm:
     cache:
       enabled: true
       ttl_seconds: 3600  # 1 hour
   ```

---

## 💬 Chat Bridge Issues

### ❌ "Chat messages not captured"

**Symptoms:**
- Chat bridge plugin loaded
- Messages not appearing in AI logs
- No responses generated

**Solutions:**

1. **Verify plugin is loaded**
   ```bash
   # Check OpenKore console for:
   # [ChatBridge] Plugin loaded - monitoring chat messages
   ```

2. **Test with manual injection**
   ```perl
   # In OpenKore console
   call GodTierChatBridge::inject_test_message('TestPlayer', 'public', 'Hello bot!')
   call print(GodTierChatBridge::dump_buffer())
   ```

3. **Check hook registration**
   ```perl
   # Verify hook exists
   call print("Hook registered: " . (exists $Plugins::hooks{'ChatQueue::add'} ? "Yes" : "No") . "\n")
   ```

4. **Review filter settings**
   - Self-messages should be filtered
   - Check if sender is being blocked
   - Verify channel mapping

**Verification:**
```bash
# Send message in game, check AI logs
grep "Chat message" ai_sidecar_log.txt
```

---

### ❌ "Chat responses not sending"

**Symptoms:**
- AI generates chat responses
- Messages don't appear in game

**Solutions:**

1. **Check chat permissions**
   ```perl
   # Verify character can chat
   # Some servers have new character restrictions
   ```

2. **Verify action format**
   ```json
   {
     "type": "chat_send",
     "message": "Hello!",
     "channel": "public"
   }
   ```

3. **Check rate limiting**
   ```yaml
   behaviors:
     social:
       chat_rate_limit_messages_per_minute: 10
   ```

4. **Review spam prevention**
   - Some servers auto-mute spam
   - Check server chat rules

---

## 🖥️ Platform-Specific Issues

### Linux Issues

#### ❌ "Permission denied"

**Solutions:**
```bash
# Make scripts executable
chmod +x validate_bridges.sh
chmod +x ai_sidecar/test_bridge_connection.py

# Fix directory permissions
chmod 755 ai_sidecar/
chmod 755 plugins/
```

#### ❌ "Library not found"

**Solutions:**
```bash
# Install ZeroMQ development files
sudo apt-get install libzmq3-dev  # Debian/Ubuntu
sudo yum install zeromq-devel      # RHEL/CentOS
brew install zeromq                # macOS

# Then reinstall Perl module
cpanm --force ZMQ::FFI
```

---

### Windows Issues

#### ❌ "Perl module install fails"

**Solutions:**
```bash
# Use Strawberry Perl (recommended)
# Download from: https://strawberryperl.com/

# Or try PPM (ActivePerl)
ppm install ZMQ-FFI
ppm install JSON-XS

# Or CPAN
cpan install ZMQ::FFI
```

#### ❌ "Scripts won't run"

**Solutions:**
```bash
# Run batch file as administrator
# Right-click → Run as administrator

# Or enable script execution
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

### macOS Issues

#### ❌ "ZeroMQ build errors"

**Solutions:**
```bash
# Install Xcode Command Line Tools
xcode-select --install

# Install ZeroMQ via Homebrew
brew install zeromq
brew install pkg-config

# Then install Perl module
cpanm ZMQ::FFI
```

---

## 🔍 Debug Mode

### Enable Full Debug Logging

**AI Sidecar:**
```bash
export AI_DEBUG_MODE=true
export AI_LOG_LEVEL=DEBUG
python main.py > ai_debug.log 2>&1
```

**OpenKore:**
```perl
# In console
call $config{AI_Bridge_debug} = 1
call $config{AI_Bridge_log_state} = 1  # Very verbose!
```

**What to look for:**
- State update messages (every tick)
- Decision generation steps
- Action application attempts
- Error messages with stack traces
- Memory operations
- LLM API calls (if using)

---

## 📞 Getting Help

### Before Asking for Help

Gather this information:

1. **System Information:**
   ```bash
   uname -a  # Linux/Mac
   systeminfo  # Windows
   ```

2. **Version Information:**
   ```bash
   python --version
   perl -v
   git log -1 --oneline  # OpenKore version
   ```

3. **Validation Results:**
   ```bash
   ./validate_bridges.sh > validation.txt 2>&1
   python ai_sidecar/test_bridge_connection.py > test.txt 2>&1
   ```

4. **Recent Logs:**
   - Last 50 lines from AI Sidecar
   - Last 50 lines from OpenKore console
   - Any error messages

### Support Channels

- **📚 Documentation:** [docs/GODTIER-RO-AI-DOCUMENTATION.md](docs/GODTIER-RO-AI-DOCUMENTATION.md)
- **🧪 Testing Guide:** [docs/BRIDGE_TESTING_GUIDE.md](docs/BRIDGE_TESTING_GUIDE.md)
- **💬 Discord:** [OpenKore Community](https://discord.com/invite/hdAhPM6)
- **🌐 Forum:** [OpenKore Forums](https://forums.openkore.com/)
- **🐛 GitHub:** [Issue Tracker](https://github.com/OpenKore/openkore/issues)

---

## 🔧 Emergency Fixes

### Complete Reset

If all else fails, start fresh:

```bash
# 1. Stop everything
pkill -f python.*main.py
pkill -f perl.*openkore

# 2. Clean up
cd ai_sidecar
rm -rf .venv __pycache__ *.log
rm -f data/memory.db

# 3. Reinstall
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# 4. Verify
python test_bridge_connection.py

# 5. Restart
python main.py
```

### Rollback to Safe State

```bash
# If recent update broke something
git log --oneline -10  # See recent commits
git checkout <last-working-commit>

# Or revert to stable release
git checkout v3.0.0
```

---

## ✅ Verification After Fix

After applying any fix:

1. **Run validation**
   ```bash
   ./validate_bridges.sh
   ```

2. **Test connection**
   ```bash
   python ai_sidecar/test_bridge_connection.py
   ```

3. **Monitor for 15 minutes**
   - Watch both terminals
   - Check for errors
   - Verify actions executing

4. **Document the fix**
   - Note what was broken
   - Note what fixed it
   - Share if it's a common issue

---

**Last Updated:** December 5, 2025  
**Version:** 1.0.0  
**Maintainer:** OpenKore-AI Team