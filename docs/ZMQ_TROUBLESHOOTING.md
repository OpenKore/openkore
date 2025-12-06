# 🔧 ZeroMQ Troubleshooting Guide

> **Comprehensive troubleshooting for ZeroMQ connectivity issues across all platforms**

**Version:** 1.0.0  
**Last Updated:** December 6, 2025  
**Covers:** Windows, Linux, macOS, WSL, Docker

---

## 📑 Table of Contents

- [Quick Diagnosis](#-quick-diagnosis)
- [Platform-Specific Issues](#-platform-specific-issues)
  - [Windows Issues](#windows-issues)
  - [Linux/Unix Issues](#linuxunix-issues)
  - [macOS Issues](#macos-issues)
  - [WSL Issues](#wsl-issues)
  - [Docker Issues](#docker-issues)
- [Error Messages Reference](#-error-messages-reference)
- [Connection Testing](#-connection-testing)
- [Performance Issues](#-performance-issues)
- [Advanced Debugging](#-advanced-debugging)

---

## 🔍 Quick Diagnosis

### Immediate Checks

Run these commands to diagnose your issue quickly:

**1. Check Platform Detection**:
```bash
cd ai_sidecar
python -c "from ai_sidecar.utils.platform import detect_platform; info = detect_platform(); print(f'Platform: {info.platform_name}'); print(f'IPC Support: {info.can_use_ipc}'); print(f'Default: {info.default_endpoint}')"
```

**2. Verify Endpoint Configuration**:
```bash
# Check Python side
python -c "from ai_sidecar.config import get_settings; print(get_settings().zmq.endpoint)"

# Check Perl side
grep "AI_Bridge_address" ../plugins/AI_Bridge/AI_Bridge.txt || grep "AI_Bridge_address" ../plugins/AI_Bridge.pl
```

**3. Test Port/Socket Availability**:

**Linux/macOS**:
```bash
# For TCP endpoint
lsof -i :5555

# For IPC socket
ls -la /tmp/openkore-ai.sock
```

**Windows (PowerShell)**:
```powershell
# Check port 5555
Get-NetTCPConnection -LocalPort 5555 -ErrorAction SilentlyContinue
```

### Decision Tree

```
Is AI Sidecar starting?
├─ NO → See "AI Sidecar Won't Start"
└─ YES → Is OpenKore connecting?
    ├─ NO → See "Connection Failed"
    └─ YES → Is communication working?
        ├─ NO → See "Connection Drops"
        └─ YES → See "Performance Issues"
```

---

## 🌍 Platform-Specific Issues

### Windows Issues

#### ❌ Issue: "IPC not supported on Windows"

**Full Error**:
```
PlatformCompatibilityError: IPC endpoint 'ipc:///tmp/openkore-ai.sock' is not supported on Windows
```

**Cause**: Trying to use Unix IPC sockets on Windows

**Solution 1: Use Automatic Detection** (Recommended)
```bash
# In ai_sidecar/.env
# Remove or comment out this line:
# AI_ZMQ_ENDPOINT=ipc:///tmp/openkore-ai.sock

# System will automatically use TCP
```

**Solution 2: Explicitly Set TCP**
```bash
# In ai_sidecar/.env
AI_ZMQ_ENDPOINT=tcp://127.0.0.1:5555
```

**Solution 3: Check for Copy-Paste Errors**
- Ensure you didn't copy Linux/macOS configuration
- Delete `.env` and recreate from `.env.example`
- Let system auto-detect platform

**Verification**:
```powershell
# Should show TCP endpoint
python -c "from ai_sidecar.config import get_settings; print(get_settings().zmq.endpoint)"
```

---

#### ❌ Issue: Port 5555 Already in Use

**Error**:
```
OSError: [WinError 10048] Only one usage of each socket address is normally permitted
```

**Diagnosis**:
```powershell
# Find what's using port 5555
Get-NetTCPConnection -LocalPort 5555 | 
  Select-Object LocalAddress, LocalPort, State, OwningProcess |
  ForEach-Object {
    $proc = Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue
    [PSCustomObject]@{
      Port = $_.LocalPort
      State = $_.State
      ProcessId = $_.OwningProcess
      ProcessName = $proc.ProcessName
      Path = $proc.Path
    }
  } | Format-Table
```

**Solution 1: Stop Conflicting Process**
```powershell
# If it's another AI Sidecar instance:
Get-Process python | Where-Object {$_.Path -like "*openkore*"} | Stop-Process

# If it's a specific process ID (replace 1234):
Stop-Process -Id 1234

# If it's a known service:
Stop-Service ServiceName
```

**Solution 2: Use Different Port**
```bash
# In ai_sidecar/.env
AI_ZMQ_ENDPOINT=tcp://127.0.0.1:5556

# IMPORTANT: Also update plugins/AI_Bridge/AI_Bridge.txt
# AI_Bridge_address tcp://127.0.0.1:5556
```

**Solution 3: Kill All Python Processes** (Nuclear Option)
```powershell
# ⚠️ WARNING: Kills ALL Python processes
Get-Process python | Stop-Process -Force

# Restart AI Sidecar
```

**Prevention**:
- Always shutdown AI Sidecar gracefully (Ctrl+C)
- Use Task Manager to ensure no orphaned processes
- Consider using unique ports for multiple bots

---

#### ❌ Issue: Firewall Blocks Connection

**Symptoms**:
- AI Sidecar starts but OpenKore can't connect
- Firewall popup appears
- Connection times out

**Check Firewall Status**:
```powershell
# Check if Windows Firewall is blocking Python
Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*Python*"}
```

**Solution 1: Allow via Firewall Popup**
1. When AI Sidecar starts, Windows may show popup
2. Check "Private networks"
3. Click "Allow access"

**Solution 2: Add Firewall Rule Manually**
```powershell
# Run PowerShell as Administrator

# Allow Python for private networks only
New-NetFirewallRule -DisplayName "OpenKore AI Sidecar" `
  -Direction Inbound `
  -Program "C:\path\to\openkore-AI\.venv\Scripts\python.exe" `
  -Action Allow `
  -Profile Private `
  -Protocol TCP `
  -LocalPort 5555

# Verify rule
Get-NetFirewallRule -DisplayName "OpenKore AI Sidecar"
```

**Solution 3: Disable Firewall Temporarily** (Testing Only)
```powershell
# ⚠️ ONLY for testing - re-enable after!
# Requires Administrator
Set-NetFirewallProfile -Profile Private -Enabled False

# Test connection

# Re-enable immediately
Set-NetFirewallProfile -Profile Private -Enabled True
```

---

#### ❌ Issue: Antivirus Blocking AI Sidecar

**Symptoms**:
- Installation fails with access denied
- AI Sidecar crashes on startup
- Very slow performance
- Files disappear after download

**Common Antiviruses**:
- Windows Defender
- Norton
- McAfee
- Avast
- AVG
- Kaspersky

**Solution: Add Exclusions**

**Windows Defender**:
1. Open "Windows Security"
2. Click "Virus & threat protection"
3. Scroll to "Virus & threat protection settings"
4. Click "Manage settings"
5. Scroll to "Exclusions"
6. Click "Add or remove exclusions"
7. Click "Add an exclusion" → "Folder"
8. Browse to: `C:\path\to\openkore-AI`
9. Click "Select Folder"

**Via PowerShell** (Administrator):
```powershell
# Add folder exclusion
Add-MpPreference -ExclusionPath "C:\path\to\openkore-AI"

# Add process exclusion
Add-MpPreference -ExclusionProcess "python.exe"

# Verify exclusions
Get-MpPreference | Select-Object ExclusionPath, ExclusionProcess
```

**Third-Party Antivirus**:
- Consult your antivirus documentation
- Add entire `openkore-AI` folder to exclusions
- Add `python.exe` to trusted applications

---

#### ❌ Issue: PowerShell Execution Policy

**Error**:
```
.venv\Scripts\Activate.ps1 cannot be loaded because running scripts is disabled on this system
```

**Cause**: PowerShell script execution disabled

**Solution**:
```powershell
# Check current policy
Get-ExecutionPolicy

# Set to RemoteSigned (recommended)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Verify
Get-ExecutionPolicy
# Should show: RemoteSigned

# Alternative: Bypass for current session only
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Now activate venv
.\.venv\Scripts\Activate.ps1
```

**Alternative**: Use Command Prompt (cmd.exe)
```cmd
# No execution policy issues with .bat files
.venv\Scripts\activate.bat
```

---

### Linux/Unix Issues

#### ❌ Issue: Stale Socket File

**Error**:
```
zmq.error.ZMQError: Address already in use
```

**Cause**: Previous AI Sidecar process crashed, leaving socket file

**Automatic Cleanup** (Phase 2 Feature):
The system now **automatically detects and removes stale sockets**!

**Manual Cleanup** (if automatic fails):
```bash
# Check if socket exists
ls -la /tmp/openkore-ai.sock

# Check if it's in use
lsof /tmp/openkore-ai.sock

# If no process listed, it's stale - remove it
rm /tmp/openkore-ai.sock

# Restart AI Sidecar
python main.py
```

**Prevent Future Issues**:
```bash
# Always shutdown gracefully (Ctrl+C)
# Avoid kill -9 which prevents cleanup

# Create cleanup script
cat > cleanup_socket.sh << 'EOF'
#!/bin/bash
rm -f /tmp/openkore-ai.sock
echo "✅ Socket cleaned"
EOF

chmod +x cleanup_socket.sh
./cleanup_socket.sh
```

---

#### ❌ Issue: Permission Denied on /tmp

**Error**:
```
PermissionError: [Errno 13] Permission denied: '/tmp/openkore-ai.sock'
```

**Cause**: Insufficient permissions on /tmp directory

**Check Permissions**:
```bash
ls -ld /tmp
# Should show: drwxrwxrwt (world-writable with sticky bit)

# Check if you can write to /tmp
touch /tmp/test.txt && rm /tmp/test.txt && echo "✅ /tmp writable" || echo "❌ /tmp not writable"
```

**Solution 1: Fix /tmp Permissions** (if corrupted)
```bash
# Requires sudo
sudo chmod 1777 /tmp

# Verify
ls -ld /tmp
```

**Solution 2: Use Alternative Location**
```bash
# In .env
AI_ZMQ_ENDPOINT=ipc:///var/run/openkore-ai.sock

# Create directory with proper permissions
sudo mkdir -p /var/run
sudo chmod 755 /var/run
```

**Solution 3: Use User-Specific Location**
```bash
# In .env
AI_ZMQ_ENDPOINT=ipc://${HOME}/.openkore/ai.sock

# Create directory
mkdir -p ~/.openkore
```

**Solution 4: Use TCP Instead**
```bash
# Bypass file permission issues entirely
AI_ZMQ_ENDPOINT=tcp://127.0.0.1:5555
```

---

#### ❌ Issue: Socket Cleanup Fails

**Error**:
```
SocketCleanupError: Failed to remove stale socket: Permission denied
```

**Diagnosis**:
```bash
# Check socket ownership
ls -l /tmp/openkore-ai.sock

# Check your user
whoami

# Check if socket is in use
lsof /tmp/openkore-ai.sock
fuser /tmp/openkore-ai.sock
```

**Solution 1: Remove as Owner**
```bash
# If you own the socket
rm /tmp/openkore-ai.sock

# If permission denied, check attributes
lsattr /tmp/openkore-ai.sock
```

**Solution 2: Remove as Root**
```bash
# ⚠️ Use with caution
sudo rm /tmp/openkore-ai.sock

# Fix permissions for future
sudo chown $USER:$USER /tmp/openkore-ai.sock
```

**Solution 3: Different Socket Location**
```bash
# Use location you control
AI_ZMQ_ENDPOINT=ipc://${HOME}/.openkore/ai.sock
```

---

### macOS Issues

#### ❌ Issue: /tmp Cleaned on Reboot

**Symptom**: Socket works, then disappears after reboot

**Cause**: macOS cleans `/tmp` directory on reboot

**This is normal behavior!** The automatic cleanup system handles this.

**Alternative**: Use persistent location
```bash
# In .env
AI_ZMQ_ENDPOINT=ipc:///var/run/openkore-ai.sock

# Create directory
sudo mkdir -p /var/run
```

**Or**: Use user library
```bash
# More appropriate for user applications
AI_ZMQ_ENDPOINT=ipc://${HOME}/Library/Application Support/openkore/ai.sock

# Create directory
mkdir -p "${HOME}/Library/Application Support/openkore"
```

---

#### ❌ Issue: System Integrity Protection (SIP)

**Symptom**: Permission denied even with sudo

**Cause**: SIP protects certain directories

**Check SIP Status**:
```bash
csrutil status
```

**Solution**: Don't fight SIP - use alternative location
```bash
# Use user-writable location
AI_ZMQ_ENDPOINT=ipc://${HOME}/.openkore/ai.sock

# Or use TCP
AI_ZMQ_ENDPOINT=tcp://127.0.0.1:5555
```

---

### WSL Issues

#### ❌ Issue: WSL Version Detection Fails

**Symptom**: System can't determine if WSL 1 or WSL 2

**Check WSL Version** (from Windows):
```powershell
wsl.exe -l -v
```

**Output Example**:
```
  NAME            STATE           VERSION
* Ubuntu-22.04    Running         2
  Debian          Stopped         1
```

**Solution 1: Explicitly Configure**
```bash
# If WSL 1, use TCP:
AI_ZMQ_ENDPOINT=tcp://127.0.0.1:5555

# If WSL 2, use IPC:
AI_ZMQ_ENDPOINT=ipc:///tmp/openkore-ai.sock
```

**Solution 2: Upgrade to WSL 2**
```powershell
# From Windows PowerShell
wsl --set-version Ubuntu-22.04 2

# Verify
wsl.exe -l -v
```

---

#### ❌ Issue: WSL Can't Connect to Windows Process

**Symptom**: AI Sidecar in WSL, OpenKore in Windows (or vice versa)

**Cause**: Network isolation between WSL and Windows

**Solution 1: Both Use TCP with Proper Addressing**

**AI Sidecar in WSL** (bind to all interfaces):
```bash
# In .env
AI_ZMQ_ENDPOINT=tcp://0.0.0.0:5555
```

**OpenKore in Windows** (connect to WSL):
```ini
# In plugins/AI_Bridge/AI_Bridge.txt
AI_Bridge_address tcp://localhost:5555
```

**Solution 2: Use WSL IP Address**
```bash
# From WSL, find IP:
hostname -I | awk '{print $1}'
# Example output: 172.24.128.45

# Use this in Windows OpenKore:
AI_Bridge_address tcp://172.24.128.45:5555
```

**Solution 3: Run Both in Same Environment**
- Both in WSL (recommended for WSL 2)
- Both in Windows

---

#### ❌ Issue: WSL File System Performance

**Symptom**: Very slow startup or high latency

**Cause**: Project in Windows filesystem (`/mnt/c/`)

**Check Current Location**:
```bash
pwd
# ❌ BAD:  /mnt/c/Users/YourName/openkore-AI
# ✅ GOOD: /home/yourname/openkore-AI
```

**Solution**: Move to WSL filesystem
```bash
# Copy project to WSL home
cp -r /mnt/c/Users/YourName/openkore-AI ~/openkore-AI

# Work from WSL filesystem
cd ~/openkore-AI
```

**Performance Comparison**:
- Windows FS (`/mnt/c/`): 10-100x slower
- WSL FS (`~/`): Native Linux speed

---

### Docker Issues

#### ❌ Issue: IPC Socket Not Accessible

**Symptom**: Socket file exists but connection fails

**Cause**: Socket not shared with container

**Solution: Volume Mount**

**Docker CLI**:
```bash
docker run -v /tmp:/tmp openkore-ai
```

**docker-compose.yml**:
```yaml
services:
  ai_sidecar:
    image: openkore-ai
    volumes:
      - /tmp:/tmp  # Share /tmp directory
    # Or mount specific socket:
    # - /tmp/openkore-ai.sock:/tmp/openkore-ai.sock
```

---

#### ❌ Issue: Container-to-Host Communication

**Symptom**: Container can't reach host

**Solution 1: Use host.docker.internal**
```bash
# In container .env
AI_ZMQ_ENDPOINT=tcp://host.docker.internal:5555
```

**Solution 2: Use Host Network Mode**
```yaml
# docker-compose.yml
services:
  ai_sidecar:
    network_mode: host
```

**Solution 3: Bridge Network with Port Mapping**
```yaml
services:
  ai_sidecar:
    ports:
      - "5555:5555"
```

---

## 📋 Error Messages Reference

### Configuration Errors

#### "Endpoint cannot be empty"

**Error**:
```
ValueError: Endpoint cannot be empty
```

**Cause**: `AI_ZMQ_ENDPOINT` set to empty string

**Solution**:
```bash
# Remove the line or set to valid endpoint
AI_ZMQ_ENDPOINT=tcp://127.0.0.1:5555

# Or comment out to use auto-detection:
# AI_ZMQ_ENDPOINT=...
```

---

#### "Invalid endpoint format"

**Error**:
```
ValueError: Invalid endpoint format: 'localhost:5555'
```

**Cause**: Missing protocol prefix (`tcp://` or `ipc://`)

**Solution**:
```bash
# ❌ WRONG: localhost:5555
# ❌ WRONG: 127.0.0.1:5555
# ✅ CORRECT: tcp://127.0.0.1:5555
AI_ZMQ_ENDPOINT=tcp://127.0.0.1:5555
```

---

#### "TCP endpoint must include port"

**Error**:
```
ValueError: TCP endpoint 'tcp://127.0.0.1' must include port
```

**Cause**: Missing port number

**Solution**:
```bash
# ❌ WRONG: tcp://127.0.0.1
# ✅ CORRECT: tcp://127.0.0.1:5555
AI_ZMQ_ENDPOINT=tcp://127.0.0.1:5555
```

---

### Connection Errors

#### "Connection refused"

**Error**:
```
ConnectionRefusedError: [Errno 111] Connection refused
```

**Cause**: AI Sidecar not running or wrong endpoint

**Diagnosis**:
```bash
# Check if AI Sidecar is running
ps aux | grep "python main.py"  # Linux/macOS
Get-Process python              # Windows

# Check endpoint matches on both sides
# Python side:
grep AI_ZMQ_ENDPOINT .env

# Perl side:
grep AI_Bridge_address ../plugins/AI_Bridge/AI_Bridge.txt
```

**Solutions**:
1. Start AI Sidecar first, then OpenKore
2. Verify endpoints match exactly
3. Check firewall/antivirus not blocking

---

#### "No such file or directory" (IPC)

**Error**:
```
FileNotFoundError: [Errno 2] No such file or directory: '/tmp/openkore-ai.sock'
```

**Cause**: IPC socket path doesn't exist or is invalid

**Solutions**:

**On Windows**: You shouldn't see this if auto-detection works
```bash
# Windows users: Use TCP
AI_ZMQ_ENDPOINT=tcp://127.0.0.1:5555
```

**On Unix**: Ensure directory exists
```bash
# Check directory exists
ls -ld /tmp
# Should exist with drwxrwxrwt permissions

# If directory missing (unlikely):
sudo mkdir -p /tmp
sudo chmod 1777 /tmp
```

---

#### "Address already in use"

See platform-specific sections:
- Windows: [Port 5555 Already in Use](#-issue-port-5555-already-in-use)
- Unix: [Stale Socket File](#-issue-stale-socket-file)

---

### Timeout Errors

#### "Receive timeout"

**Error**:
```
zmq.error.Again: Resource temporarily unavailable
```

**Cause**: No response received within timeout period

**Solutions**:

**Increase Timeouts**:
```bash
# In .env
AI_ZMQ_RECV_TIMEOUT_MS=200  # Increase from 100
AI_ZMQ_SEND_TIMEOUT_MS=200
```

**Check Connection**:
```bash
# Ensure both processes are running
# Ensure endpoints match
# Check network connectivity
```

---

## 🧪 Connection Testing

### Python to Python Test

Test if ZeroMQ works independently:

**Server** (Terminal 1):
```python
# test_server.py
import zmq
import time

context = zmq.Context()
socket = context.socket(zmq.REP)
socket.bind("tcp://127.0.0.1:5555")  # Or IPC on Unix

print("✅ Server listening on tcp://127.0.0.1:5555")

while True:
    message = socket.recv_string()
    print(f"Received: {message}")
    socket.send_string(f"Echo: {message}")
```

**Client** (Terminal 2):
```python
# test_client.py
import zmq

context = zmq.Context()
socket = context.socket(zmq.REQ)
socket.connect("tcp://127.0.0.1:5555")  # Or IPC on Unix

print("✅ Client connected")

for i in range(5):
    socket.send_string(f"Test message {i}")
    response = socket.recv_string()
    print(f"Response: {response}")

print("✅ All tests passed!")
```

**Run Test**:
```bash
# Terminal 1
python test_server.py

# Terminal 2
python test_client.py
```

**Expected Output**: 5 successful message exchanges

---

### Perl to Python Test

Test the actual bridge:

**Start AI Sidecar**:
```bash
cd ai_sidecar
python main.py
# Should show: ✅ AI Sidecar ready!
```

**Start OpenKore with Debug**:
```bash
./start.pl --verbose
# Or start.exe --verbose on Windows
```

**Watch for**:
```
[AI_Bridge] Connecting to tcp://127.0.0.1:5555
[AI_Bridge] Connected successfully
```

**Test Message Exchange**:
```perl
# In OpenKore console
# Send test command through bridge
call AIBridge::send_test_message()
```

---

### Network Connectivity Test

**TCP Connectivity**:

**Linux/macOS**:
```bash
# Test if port is listening
nc -zv 127.0.0.1 5555

# Or using telnet
telnet 127.0.0.1 5555

# Or using Python
python -c "import socket; s=socket.socket(); s.connect(('127.0.0.1', 5555)); print('✅ Connected')"
```

**Windows (PowerShell)**:
```powershell
# Test TCP connection
Test-NetConnection -ComputerName 127.0.0.1 -Port 5555

# Or using Python
python -c "import socket; s=socket.socket(); s.connect(('127.0.0.1', 5555)); print('OK')"
```

**IPC Connectivity** (Unix only):
```bash
# Test Unix socket
nc -U /tmp/openkore-ai.sock

# Or check if listening
lsof /tmp/openkore-ai.sock
```

---

## ⚡ Performance Issues

### High Latency

**Symptom**: Actions delayed, sluggish response

**Diagnosis**:
```bash
# Check tick processing time in logs
grep "tick_processing_ms" logs/ai_sidecar.log | tail -20

# Acceptable: <50ms for CPU mode, <80ms for GPU mode
# Problematic: >100ms consistently
```

**Solutions**:

**Solution 1: Optimize Tick Rate**
```bash
# Reduce decision frequency
AI_TICK_INTERVAL_MS=200  # From 100ms

# Reduce complexity per tick
AI_DECISION_MAX_ACTIONS_PER_TICK=3  # From 5
```

**Solution 2: Check Compute Backend**
```bash
# CPU mode is fastest for pure decisions
COMPUTE_BACKEND=cpu
AI_DECISION_ENGINE_TYPE=rule_based

# LLM mode is slowest (500-2000ms per decision)
# Only use for strategic decisions, not combat
```

**Solution 3: Reduce Logging**
```bash
# Less verbose logging = better performance
AI_LOG_LEVEL=WARNING  # From INFO or DEBUG
```

**Solution 4: Close Background Apps**
- Close Chrome/Firefox (memory hogs)
- Close other CPU-intensive applications
- Check Task Manager for resource usage

---

### Message Queue Backup

**Symptom**: Warnings about dropped messages

**Error**:
```
[WARNING] ZMQ high water mark reached, messages may be dropped
```

**Cause**: Messages arriving faster than processing

**Solutions**:

**Solution 1: Increase Queue Size**
```bash
# In .env
AI_ZMQ_HIGH_WATER_MARK=5000  # From 1000
```

**Solution 2: Faster Processing**
```bash
# Use faster backend
COMPUTE_BACKEND=cpu  # Fastest decisions

# Reduce per-tick complexity
AI_DECISION_MAX_ACTIONS_PER_TICK=3
```

**Solution 3: Rate Limiting on Perl Side**
```perl
# In AI_Bridge.txt
AI_Bridge_send_interval_ms 50  # Throttle sends
```

---

### Connection Drops

**Symptom**: Connection works then disconnects randomly

**Causes & Solutions**:

**Cause 1: Timeout Too Short**
```bash
# Increase timeouts
AI_ZMQ_RECV_TIMEOUT_MS=500
AI_ZMQ_SEND_TIMEOUT_MS=500
```

**Cause 2: Network Issues** (if using TCP remotely)
```bash
# Check network stability
# Use ping to monitor:
ping -t 192.168.1.100  # Windows
ping 192.168.1.100     # Unix (Ctrl+C to stop)
```

**Cause 3: System Suspend/Sleep**
```bash
# Disable power management for network adapter (Windows)
# Disable computer sleep during bot operation
```

**Cause 4: Memory Pressure**
```bash
# System killing process due to low memory
# Check system resources
free -h  # Linux
Get-ComputerInfo | Select-Object CsTotalPhysicalMemory, CsFreePhysicalMemory  # Windows
```

---

## 🔬 Advanced Debugging

### Enable Verbose Logging

**Python Side**:
```bash
# In .env
AI_DEBUG=true
AI_LOG_LEVEL=DEBUG
AI_LOG_INCLUDE_CALLER=true  # Shows file:line for each log

# Restart AI Sidecar
```

**Perl Side**:
```perl
# In AI_Bridge.txt
AI_Bridge_debug 1
```

**OpenKore Verbose Mode**:
```bash
# Linux/macOS
./start.pl --verbose

# Windows
start.exe --verbose
```

---

### Inspect ZMQ Socket State

**Python**:
```python
# In AI Sidecar code, add debugging:
import zmq

# After socket creation
print(f"Socket type: {socket.getsockopt(zmq.TYPE)}")
print(f"HWM: {socket.getsockopt(zmq.SNDHWM)}")
print(f"Linger: {socket.getsockopt(zmq.LINGER)}")
print(f"Events: {socket.getsockopt(zmq.EVENTS)}")
```

**Monitor Socket Statistics**:
```python
# Create monitoring script
import zmq
import time

context = zmq.Context()
monitor = context.socket(zmq.PAIR)
monitor.bind("inproc://monitor")

socket = context.socket(zmq.REP)
socket.monitor("inproc://monitor", zmq.EVENT_ALL)
socket.bind("tcp://127.0.0.1:5555")

while True:
    event = monitor.recv_multipart()
    print(f"Event: {event}")
```

---

### Using Network Diagnostic Tools

**Linux/macOS**:

**netstat**:
```bash
# Show listening sockets
netstat -tlnp | grep 5555

# Show established connections
netstat -anp | grep 5555
```

**lsof**:
```bash
# Show processes using port 5555
lsof -i :5555

# Show processes using socket file
lsof /tmp/openkore-ai.sock
```

**ss** (modern replacement for netstat):
```bash
# Show listening TCP sockets
ss -tlnp | grep 5555

# Show socket details
ss -x /tmp/openkore-ai.sock
```

**tcpdump** (packet inspection):
```bash
# Monitor TCP traffic on port 5555
sudo tcpdump -i lo -n port 5555 -A

# Save to file for analysis
sudo tcpdump -i lo -n port 5555 -w zmq_traffic.pcap
```

---

**Windows**:

**netstat**:
```powershell
# Show listening ports
netstat -ano | findstr :5555

# Find process ID and details
Get-NetTCPConnection -LocalPort 5555 | 
  Select-Object LocalAddress,LocalPort,State,OwningProcess
```

**Test-NetConnection**:
```powershell
# Test if port is reachable
Test-NetConnection -ComputerName 127.0.0.1 -Port 5555

# Detailed output
Test-NetConnection -ComputerName 127.0.0.1 -Port 5555 -InformationLevel Detailed
```

**Wireshark**:
1. Download from [wireshark.org](https://www.wireshark.org/)
2. Capture on "Loopback"
3. Filter: `tcp.port == 5555`
4. Analyze packet exchange

---

### Log Analysis

**Find Errors**:
```bash
# Linux/macOS
grep -i error logs/ai_sidecar.log | tail -20
grep -i zmq logs/ai_sidecar.log | tail -20

# Windows (PowerShell)
Select-String -Path logs\ai_sidecar.log -Pattern "error","zmq" | Select-Object -Last 20
```

**Find Connection Events**:
```bash
# Linux/macOS  
grep "platform_detected\|endpoint_selected\|server_binding\|client_connected" logs/ai_sidecar.log

# Windows
Select-String -Path logs\ai_sidecar.log -Pattern "platform_detected|endpoint_selected|server_binding|client_connected"
```

**Analyze Timing Issues**:
```bash
# Find slow ticks
grep "tick_processing_ms.*[0-9]{3,}" logs/ai_sidecar.log  # >100ms

# Check for timeouts
grep -i timeout logs/ai_sidecar.log
```

---

### Testing Checklist

Use this checklist to systematically diagnose issues:

#### Level 1: Basic Checks
- [ ] Python installed and in PATH
- [ ] Virtual environment activated
- [ ] Dependencies installed (`pip list`)
- [ ] Configuration file exists (`.env`)
- [ ] Platform detected correctly

#### Level 2: Configuration Checks
- [ ] Endpoint format valid (tcp:// or ipc://)
- [ ] Endpoint includes port (for TCP)
- [ ] Windows not using IPC
- [ ] Both sides use matching endpoint
- [ ] No typos in configuration

#### Level 3: Network Checks
- [ ] Port not in use by another process
- [ ] Firewall allows connection
- [ ] Localhost connectivity works (ping 127.0.0.1)
- [ ] For remote: network route exists

#### Level 4: Process Checks
- [ ] AI Sidecar process running
- [ ] OpenKore process running  
- [ ] No zombie processes
- [ ] Processes have network permissions

#### Level 5: Performance Checks
- [ ] CPU usage reasonable (<50%)
- [ ] Memory usage reasonable (<1GB for CPU mode)
- [ ] No timeout errors in logs
- [ ] Latency acceptable (<100ms)

---

## 🆘 Still Having Issues?

### Before Requesting Help

1. **Check GitHub Issues**:
   - Search existing issues: [github.com/OpenKore/openkore/issues](https://github.com/OpenKore/openkore/issues)
   - Someone may have solved your problem already

2. **Collect Diagnostic Information**:
   ```bash
   # Run diagnostic script
   python -c "
   from ai_sidecar.utils.platform import detect_platform
   from ai_sidecar.config import get_settings
   
   info = detect_platform()
   settings = get_settings()
   
   print('=== Diagnostic Information ===')
   print(f'Platform: {info.platform_name}')
   print(f'IPC Support: {info.can_use_ipc}')
   print(f'Default Endpoint: {info.default_endpoint}')
   print(f'Configured Endpoint: {settings.zmq.endpoint}')
   print(f'Decision Engine: {settings.decision.engine_type}')
   "
   ```

3. **Review Logs**:
   - Last 50 lines: `tail -50 logs/ai_sidecar.log` (Unix)
   - Last 50 lines: `Get-Content logs\ai_sidecar.log -Tail 50` (Windows)

### Getting Support

**Discord** (Fastest response):
- Join: [discord.com/invite/hdAhPM6](https://discord.com/invite/hdAhPM6)
- Channel: #ai-sidecar-support or #troubleshooting
- Provide diagnostic info and error messages

**GitHub Issues** (For bugs):
- Create issue: [github.com/OpenKore/openkore/issues/new](https://github.com/OpenKore/openkore/issues/new)
- Include:
  - OS and version
  - Python version
  - Error messages (full traceback)
  - What you've tried
  - Diagnostic information

**Forum** (For discussions):
- Post in: [forums.openkore.com](https://forums.openkore.com/)
- Search first - may already be answered

---

## 📖 Related Documentation

### Essential Reading
- **[Main README](../README.md)** - Project overview and features
- **[Windows Setup Guide](WINDOWS_SETUP_GUIDE.md)** - Complete Windows installation
- **[Cross-Platform Architecture](CROSS_PLATFORM_ZMQ_ARCHITECTURE.md)** - Technical details
- **[Bridge Integration Checklist](../BRIDGE_INTEGRATION_CHECKLIST.md)** - Validation checklist

### Technical References
- **[Platform Detection Module](../ai_sidecar/utils/platform.py)** - Source code for platform detection
- **[Socket Cleanup Module](../ai_sidecar/ipc/socket_cleanup.py)** - Automatic cleanup implementation
- **[Error Definitions](../ai_sidecar/utils/errors.py)** - All error types and messages

### External Resources
- **ZeroMQ Guide**: [zguide.zeromq.org](https://zguide.zeromq.org/)
- **pyzmq Documentation**: [pyzmq.readthedocs.io](https://pyzmq.readthedocs.io/)
- **ZMQ::FFI (Perl)**: [metacpan.org/pod/ZMQ::FFI](https://metacpan.org/pod/ZMQ::FFI)

---

## 🔑 Quick Reference

### Common Error → Solution Mapping

| Error | Platform | Solution |
|-------|----------|----------|
| IPC not supported | Windows | Use `tcp://127.0.0.1:5555` |
| Address in use | Unix | Remove `/tmp/openkore-ai.sock` |
| Address in use | Windows | Change port or kill process |
| Connection refused | All | Start AI Sidecar first |
| No such file | Windows | Use TCP, not IPC |
| Permission denied | Unix | Check `/tmp` permissions |
| Firewall block | Windows | Add firewall exception |
| Antivirus block | Windows | Add folder exclusion |

### Endpoint Format Examples

**Valid Formats**:
```bash
✅ tcp://127.0.0.1:5555          # TCP localhost
✅ tcp://0.0.0.0:5555            # TCP all interfaces
✅ tcp://192.168.1.100:5555      # TCP specific IP
✅ ipc:///tmp/openkore-ai.sock   # IPC Unix socket (Unix only)
✅ ipc:///var/run/app.sock       # IPC alternative path
```

**Invalid Formats**:
```bash
❌ localhost:5555                # Missing protocol
❌ tcp://127.0.0.1               # Missing port
❌ ipc://openkore-ai.sock        # Not absolute path
❌ tcp://127.0.0.1:5555/path     # Path not allowed for TCP
❌ ipc:///tmp/ai.sock (Windows)  # IPC on Windows
```

### Platform Capabilities Matrix

| Feature | Windows | Linux | macOS | WSL 1 | WSL 2 | Docker |
|---------|---------|-------|-------|-------|-------|--------|
| TCP Sockets | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| IPC Sockets | ❌ | ✅ | ✅ | ❌ | ✅ | ✅ |
| Auto-Detection | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Auto-Cleanup | N/A | ✅ | ✅ | N/A | ✅ | ✅ |
| Remote Access | ✅ | ✅ | ✅ | ⚠️ | ✅ | ⚠️ |

**Legend**: ✅ Supported | ❌ Not Supported | ⚠️ Limited/Complex | N/A Not Applicable

---

## 💡 Best Practices

### ✅ Do's

1. **Use automatic platform detection** - Let the system choose the endpoint
2. **Match endpoints on both sides** - Perl and Python must agree
3. **Use TCP on Windows** - It's the only option and works perfectly
4. **Use IPC on Unix** - It's faster when both processes are local
5. **Monitor logs during startup** - Catch issues early
6. **Test with validation script** - Use `validate_bridges.sh`
7. **Keep virtual environment activated** - Prevents import errors
8. **Shutdown gracefully** - Use Ctrl+C, not kill -9

### ❌ Don'ts

1. **Don't use IPC on Windows** - It will never work
2. **Don't bind to 0.0.0.0 in production** - Security risk
3. **Don't ignore platform detection warnings** - They exist for a reason
4. **Don't run multiple instances on same endpoint** - Port/socket conflict
5. **Don't edit config while processes running** - Restart required
6. **Don't set timeouts too low** - Causes spurious errors
7. **Don't use `kill -9`** - Prevents proper cleanup
8. **Don't mix Python versions** - Use virtual environment

### 🎯 Performance Best Practices

1. **Use IPC when possible** (Unix) - 2-3x faster than TCP
2. **Use localhost (127.0.0.1)** for TCP - Faster than external IP
3. **Set appropriate timeouts** - 100-200ms is good balance
4. **Limit queue size** - Prevents memory bloat
5. **Use CPU mode for combat** - Lowest latency
6. **Reserve LLM for strategy** - Too slow for real-time combat
7. **Monitor resource usage** - Prevent system slowdown

---

*Last Updated: December 6, 2025*  
*Version: 1.0.0*  
*Maintained by: OpenKore AI Team*