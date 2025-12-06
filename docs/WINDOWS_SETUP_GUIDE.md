# 🪟 Windows Setup Guide for OpenKore AI

> **Complete setup and troubleshooting guide for Windows users**

**Version:** 1.0.0  
**Last Updated:** December 6, 2025  
**Target Audience:** Windows 10/11 users

---

## 📑 Table of Contents

- [Introduction](#-introduction)
- [Prerequisites](#-prerequisites)
- [Installation](#-installation)
- [Configuration](#-configuration)
- [Verification](#-verification)
- [Common Issues](#-common-issues)
- [Performance Optimization](#-performance-optimization)
- [WSL Users](#-wsl-users)
- [Advanced Topics](#-advanced-topics)
- [FAQ](#-faq)

---

## 🎯 Introduction

This guide helps Windows users install and configure OpenKore AI with optimal settings for the Windows platform.

### Windows-Specific Considerations

**ZeroMQ Transport**:
- ❌ **IPC sockets** (Unix domain sockets) are **NOT supported** on Windows
- ✅ **TCP sockets** are the **only option** and work perfectly
- 🎯 The system **automatically detects Windows** and uses TCP

**Key Differences from Unix**:
- No socket file cleanup needed (TCP doesn't create persistent files)
- Slightly higher latency (1-2ms vs <1ms for IPC)
- Port management instead of file permissions
- Firewall considerations for network access

**Good News**: The AI Sidecar automatically handles all Windows-specific configuration!

---

## 📋 Prerequisites

### System Requirements

#### Minimum Requirements
- **OS**: Windows 10 (version 1903+) or Windows 11
- **CPU**: Intel/AMD dual-core @ 2.0GHz or better
- **RAM**: 4GB total (2GB available)
- **Storage**: 2GB free space
- **Network**: Localhost connectivity (always available)

#### Recommended Requirements
- **OS**: Windows 11 (latest updates)
- **CPU**: Intel/AMD quad-core @ 2.5GHz or better
- **RAM**: 8GB total (4GB available)
- **Storage**: 5GB free space (10GB for GPU mode)
- **GPU**: NVIDIA GeForce GTX 1060+ with 6GB VRAM (for GPU mode)

### Required Software

#### 1. Python 3.11 or Higher

**Download**: [python.org/downloads](https://www.python.org/downloads/)

**Installation Steps**:
1. Download the latest Python 3.12.x installer (64-bit recommended)
2. Run the installer
3. ⚠️ **CRITICAL**: Check **"Add Python to PATH"** during installation
4. Click "Install Now"
5. Wait for installation to complete

**Verification**:
```powershell
# Open PowerShell and run:
python --version
# Expected output: Python 3.12.x or Python 3.11.x

# Check pip is available:
pip --version
# Expected output: pip 24.x from ...
```

**Troubleshooting Python Installation**:

If `python --version` fails:
1. Restart PowerShell/Command Prompt
2. Check if Python is in PATH:
   ```powershell
   $env:PATH -split ';' | Select-String Python
   ```
3. Manually add to PATH:
   - Search "Environment Variables" in Windows
   - Edit System Path
   - Add: `C:\Users\YourName\AppData\Local\Programs\Python\Python312`
   - Add: `C:\Users\YourName\AppData\Local\Programs\Python\Python312\Scripts`

#### 2. Git for Windows

**Download**: [git-scm.com/download/win](https://git-scm.com/download/win)

**Installation Steps**:
1. Download Git for Windows installer
2. Run installer with default options
3. Complete installation
4. Restart terminal after installation

**Verification**:
```powershell
git --version
# Expected output: git version 2.43.0 or newer
```

#### 3. Visual C++ Redistributable (Often Required)

Some Python packages require Visual C++ runtime libraries.

**Download**: [Microsoft Visual C++ Redistributable](https://aka.ms/vs/17/release/vc_redist.x64.exe)

**Installation**:
1. Download and run the installer
2. Accept license agreement
3. Click Install
4. Restart if prompted

### Optional Software

#### Perl (For OpenKore)

**Download**: [Strawberry Perl](https://strawberryperl.com/)

**Installation**:
1. Download 64-bit MSI installer
2. Run installer with default settings
3. Perl and required modules will be installed

**Verification**:
```cmd
perl --version
# Expected output: This is perl 5, version 38...
```

#### Windows Terminal (Recommended)

Modern terminal with tabs and better rendering.

**Download**: From Microsoft Store (free) or [GitHub](https://github.com/microsoft/terminal/releases)

**Benefits**:
- Multiple terminal tabs
- Better Unicode support
- Customizable appearance
- Git Bash integration

---

## 🚀 Installation

### Step-by-Step Installation

#### Step 1: Open PowerShell

**Recommended**: Windows Terminal with PowerShell
**Alternative**: Windows PowerShell (built-in)

**How to Open**:
- Press `Win + X`
- Select "Windows PowerShell" or "Terminal"

**Or**:
- Press `Win + R`
- Type `powershell`
- Press Enter

#### Step 2: Clone the Repository

```powershell
# Navigate to your preferred directory
cd C:\Users\YourName\Documents

# Clone the repository
git clone https://github.com/OpenKore/openkore.git openkore-AI

# Enter the directory
cd openkore-AI
```

**Alternative** (if repository already exists):
```powershell
cd C:\path\to\existing\openkore-AI
```

#### Step 3: Create Virtual Environment

Virtual environments keep Python packages isolated and prevent conflicts.

```powershell
# Create virtual environment
python -m venv .venv

# Activate virtual environment
.\.venv\Scripts\Activate.ps1
```

**Expected Output**:
```
(.venv) PS C:\Users\YourName\Documents\openkore-AI>
```

The `(.venv)` prefix indicates the virtual environment is active.

**If you get an execution policy error**:
```powershell
# Run this once to allow script execution:
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Then activate again:
.\.venv\Scripts\Activate.ps1
```

#### Step 4: Upgrade pip

```powershell
# Upgrade pip to latest version
python -m pip install --upgrade pip setuptools wheel
```

**Expected Output**:
```
Successfully installed pip-24.x setuptools-xx.x wheel-x.x
```

#### Step 5: Install Dependencies

```powershell
# Install AI Sidecar in editable mode
pip install -e .

# Wait for installation to complete
# This may take 2-5 minutes depending on your internet speed
```

**Expected Output**:
```
Successfully installed ai-sidecar-3.0.0 pyzmq-25.1.x pydantic-2.5.x ...
```

**Verification**:
```powershell
# Test import
python -c "import ai_sidecar; print('✅ AI Sidecar installed successfully!')"

# Check installed packages
pip list | Select-String -Pattern "zmq|pydantic|structlog"
```

#### Step 6: Configure Environment

```powershell
# Navigate to AI Sidecar directory
cd ai_sidecar

# Copy example configuration
Copy-Item .env.example .env

# Edit with Notepad
notepad .env

# Or use VS Code if installed
code .env
```

**Minimal Configuration** (for testing):

```bash
# Core Settings
AI_DEBUG=false
AI_LOG_LEVEL=INFO

# ZeroMQ - Leave unset for automatic TCP selection
# AI_ZMQ_ENDPOINT will auto-configure to tcp://127.0.0.1:5555

# Compute Backend
COMPUTE_BACKEND=cpu
AI_DECISION_ENGINE_TYPE=rule_based
```

**Save and close** the file.

#### Step 7: Verify Installation

```powershell
# Test configuration loading
python -c "from ai_sidecar.config import get_settings; s = get_settings(); print(f'✅ Config loaded! Backend: {s.decision.engine_type}')"

# Check platform detection
python -c "from ai_sidecar.utils.platform import detect_platform; info = detect_platform(); print(f'Platform: {info.platform_name}'); print(f'Default endpoint: {info.default_endpoint}')"
```

**Expected Output**:
```
✅ Config loaded! Backend: rule_based
Platform: Windows
Default endpoint: tcp://127.0.0.1:5555
```

#### Step 8: Install Perl Modules (For OpenKore)

OpenKore requires Perl with specific modules.

**Using Strawberry Perl** (includes most needed modules):
```powershell
# Check if ZMQ module is available
perl -MZMQ::FFI -e "print 'ZMQ::FFI OK\n'"

# If not available, install using cpanm:
cpanm ZMQ::FFI
cpanm JSON::XS
```

**If `cpanm` not found**:
```powershell
# Install cpanminus first
perl -MCPAN -e "install App::cpanminus"

# Then install modules
cpanm ZMQ::FFI JSON::XS
```

---

## ⚙️ Configuration

### Automatic Configuration (Recommended)

The AI Sidecar automatically configures itself for Windows:

✅ **Detects Windows platform**  
✅ **Selects TCP endpoint** (`tcp://127.0.0.1:5555`)  
✅ **Skips IPC socket cleanup** (not applicable on Windows)  
✅ **Validates configuration** to prevent IPC on Windows

**No manual configuration needed!**

### Manual Configuration (Advanced)

If you need to customize settings, edit `ai_sidecar/.env`:

#### ZeroMQ Endpoint

```bash
# Default (recommended) - uses localhost only
AI_ZMQ_ENDPOINT=tcp://127.0.0.1:5555

# Alternative port (if 5555 in use)
AI_ZMQ_ENDPOINT=tcp://127.0.0.1:5556

# Listen on all interfaces (⚠️ SECURITY RISK)
# Only use if you need remote access
AI_ZMQ_ENDPOINT=tcp://0.0.0.0:5555

# Specific network interface
AI_ZMQ_ENDPOINT=tcp://192.168.1.100:5555
```

**⚠️ Security Warning**: Using `0.0.0.0` exposes the AI Sidecar to your entire network. Only use with proper firewall rules!

#### Compute Backend

```bash
# CPU mode (default, works on any hardware)
COMPUTE_BACKEND=cpu
AI_DECISION_ENGINE_TYPE=rule_based

# GPU mode (requires NVIDIA GPU with CUDA)
COMPUTE_BACKEND=gpu
AI_DECISION_ENGINE_TYPE=ml

# LLM mode (requires API key)
COMPUTE_BACKEND=llm
OPENAI_API_KEY=sk-proj-xxxxxxxxxx
```

#### Performance Settings

```bash
# Tick rate (how often AI makes decisions)
AI_TICK_INTERVAL_MS=100  # 10 decisions/second

# Decision limits
AI_DECISION_MAX_ACTIONS_PER_TICK=5

# Memory limits
AI_MAX_MEMORY_MB=512
```

### Perl Side Configuration

Ensure OpenKore's Perl side matches the Python configuration:

**File**: `plugins/AI_Bridge/AI_Bridge.txt`

```ini
# Must match AI Sidecar endpoint
AI_Bridge_address tcp://127.0.0.1:5555

# Other settings
AI_Bridge_enabled 1
AI_Bridge_timeout_ms 50
AI_Bridge_debug 0
```

**⚠️ Critical**: Both Python (.env) and Perl (AI_Bridge.txt) must use the **same endpoint**!

---

## ✅ Verification

### Step 1: Test Platform Detection

```powershell
cd ai_sidecar

# Check platform detection
python -c "from ai_sidecar.utils.platform import detect_platform; info = detect_platform(); print(info)"
```

**Expected Output**:
```
Platform: Windows | IPC: ✗ | Default: tcp://127.0.0.1:5555
```

### Step 2: Start AI Sidecar

```powershell
# Ensure virtual environment is activated
.\.venv\Scripts\Activate.ps1

# Start AI Sidecar
cd ai_sidecar
python main.py
```

**Expected Output**:
```
[INFO] Platform detected: Windows
[INFO] Using endpoint: tcp://127.0.0.1:5555 (automatic)
[INFO] AI Sidecar starting v3.0.0
[INFO] ZeroMQ server binding to tcp://127.0.0.1:5555
✅ AI Sidecar ready! Listening on: tcp://127.0.0.1:5555
[INFO] Waiting for OpenKore connection...
```

### Step 3: Start OpenKore

Open a **new PowerShell window**:

```powershell
cd C:\path\to\openkore-AI
start.exe
```

**Expected Output** (in OpenKore console):
```
[Plugins] Loading plugin plugins/AI_Bridge.pl...
[AI_Bridge] Connecting to AI sidecar at tcp://127.0.0.1:5555
[AI_Bridge] Connected successfully
✅ God-Tier AI activated!
```

### Step 4: Verify Connection

**In AI Sidecar window**, you should see:
```
[INFO] OpenKore client connected
[INFO] State updates being received
```

**In OpenKore console**, type:
```perl
# Check connection status
call print("Bridge connected: " . ($AI_Bridge::state{connected} ? "YES" : "NO") . "\n")
```

**Expected Output**: `Bridge connected: YES`

### Step 5: Test Basic Functionality

1. **Login to game** (configure `control/config.txt` first)
2. **Watch AI Sidecar logs** - should show state updates
3. **Watch OpenKore console** - should show AI decisions
4. **Character should respond** to game events automatically

✅ **Success**: If all steps pass, your installation is working!

---

## ⚠️ Common Issues

### Issue 1: "Python not recognized"

**Symptom**:
```
'python' is not recognized as an internal or external command
```

**Cause**: Python not in PATH

**Solution**:
```powershell
# Option 1: Reinstall Python with "Add to PATH" checked

# Option 2: Use full path
C:\Users\YourName\AppData\Local\Programs\Python\Python312\python.exe --version

# Option 3: Create alias in PowerShell profile
Set-Alias python "C:\Users\YourName\AppData\Local\Programs\Python\Python312\python.exe"

# Option 4: Add to PATH manually
# Search Windows: "Environment Variables"
# Edit "Path" variable
# Add Python installation directory
```

**Verify Fix**:
```powershell
python --version
# Should now work
```

---

### Issue 2: Port 5555 Already in Use

**Symptom**:
```
[ERROR] Address already in use: tcp://127.0.0.1:5555
```

**Cause**: Another program is using port 5555

**Check What's Using the Port**:
```powershell
# Find process using port 5555
Get-NetTCPConnection -LocalPort 5555 -ErrorAction SilentlyContinue | 
  Select-Object LocalAddress,LocalPort,State,OwningProcess |
  ForEach-Object { 
    $_ | Add-Member -NotePropertyName ProcessName -NotePropertyValue (Get-Process -Id $_.OwningProcess).ProcessName -PassThru
  }
```

**Solutions**:

**Solution 1: Stop the conflicting process**
```powershell
# If it's another AI Sidecar instance:
Get-Process python | Where-Object {$_.Path -like "*openkore*"} | Stop-Process

# If it's a different service, stop it or change its port
```

**Solution 2: Use a different port**
```bash
# In ai_sidecar/.env
AI_ZMQ_ENDPOINT=tcp://127.0.0.1:5556

# IMPORTANT: Also update plugins/AI_Bridge/AI_Bridge.txt:
# AI_Bridge_address tcp://127.0.0.1:5556
```

**Solution 3: Check for "zombie" processes**
```powershell
# Kill all Python processes (⚠️ use with caution)
Get-Process python | Stop-Process -Force
```

---

### Issue 3: Firewall Blocking Connection

**Symptom**:
```
[ERROR] Connection refused
[ERROR] No route to host
```

**Cause**: Windows Defender Firewall blocking Python

**Solution**:

**Option 1: Add Firewall Rule** (Recommended)
```powershell
# Run PowerShell as Administrator
# Allow Python through firewall for private networks
New-NetFirewallRule -DisplayName "OpenKore AI Sidecar" `
  -Direction Inbound `
  -Program "C:\Users\YourName\Documents\openkore-AI\.venv\Scripts\python.exe" `
  -Action Allow `
  -Profile Private

# Verify rule was created
Get-NetFirewallRule -DisplayName "OpenKore AI Sidecar"
```

**Option 2: Temporarily Disable Firewall** (Testing Only)
```powershell
# ⚠️ NOT RECOMMENDED for production
# Disable Windows Defender Firewall (requires admin)
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# Re-enable after testing
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
```

**Option 3: Allow via GUI**
1. Search Windows: "Windows Defender Firewall"
2. Click "Allow an app through firewall"
3. Click "Change settings" (requires admin)
4. Click "Allow another app"
5. Browse to: `.venv\Scripts\python.exe`
6. Check "Private" networks only
7. Click "Add"

---

### Issue 4: Antivirus Interference

**Symptom**:
- Installation fails with access denied
- AI Sidecar crashes randomly
- Slow performance

**Cause**: Antivirus scanning Python processes

**Solutions**:

**Solution 1: Add Exclusions** (Recommended)

**Windows Defender**:
1. Search Windows: "Windows Security"
2. Go to "Virus & threat protection"
3. Click "Manage settings"
4. Scroll to "Exclusions"
5. Click "Add or remove exclusions"
6. Add folder exclusion: `C:\Users\YourName\Documents\openkore-AI`

**Third-Party Antivirus** (e.g., Norton, McAfee):
- Consult your antivirus documentation
- Add `openkore-AI` folder to exclusions
- Add `.venv\Scripts\python.exe` to trusted applications

**Solution 2: Temporarily Disable** (Testing Only)
```powershell
# ⚠️ Only for testing - not recommended
# Disable Windows Defender Real-time Protection temporarily
# (Settings → Virus & threat protection → Manage settings)
```

---

### Issue 5: "Access Denied" / Permission Errors

**Symptom**:
```
PermissionError: [WinError 5] Access is denied
```

**Cause**: Insufficient permissions or file in use

**Solutions**:

**Solution 1: Run as Administrator**
```powershell
# Right-click PowerShell
# Select "Run as Administrator"
# Navigate to project and try again
```

**Solution 2: Check File Ownership**
```powershell
# Check who owns the directory
Get-Acl C:\path\to\openkore-AI | Format-List

# Take ownership if needed (run as admin)
takeown /F C:\path\to\openkore-AI /R /D Y
```

**Solution 3: Close Interfering Applications**
- Close any text editors with project files open
- Close any terminals running from the directory
- Restart Windows if permissions persist

---

### Issue 6: Virtual Environment Activation Fails

**Symptom**:
```
.\.venv\Scripts\Activate.ps1 : File cannot be loaded because running scripts is disabled
```

**Cause**: PowerShell execution policy prevents script execution

**Solution**:
```powershell
# Check current policy
Get-ExecutionPolicy

# Set to RemoteSigned (recommended)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Verify change
Get-ExecutionPolicy
# Should show: RemoteSigned

# Try activation again
.\.venv\Scripts\Activate.ps1
```

**Alternative**: Use Command Prompt instead
```cmd
# In Command Prompt (cmd.exe):
.venv\Scripts\activate.bat
```

---

### Issue 7: Module Import Errors

**Symptom**:
```
ModuleNotFoundError: No module named 'ai_sidecar'
```

**Cause**: Package not installed or wrong Python environment

**Solutions**:

**Solution 1: Ensure Virtual Environment is Active**
```powershell
# Check if (.venv) prefix is shown
# If not, activate:
.\.venv\Scripts\Activate.ps1

# Verify Python location
Get-Command python | Select-Object Source
# Should point to .venv\Scripts\python.exe
```

**Solution 2: Reinstall Package**
```powershell
# Navigate to project root
cd C:\path\to\openkore-AI

# Activate venv
.\.venv\Scripts\Activate.ps1

# Install package
pip install -e .
```

**Solution 3: Check PYTHONPATH**
```powershell
# Add project root to PYTHONPATH temporarily
$env:PYTHONPATH = "C:\path\to\openkore-AI;$env:PYTHONPATH"

# Test import again
python -c "import ai_sidecar; print('OK')"
```

---

### Issue 8: IPC Socket Error on Windows

**Symptom**:
```
PlatformCompatibilityError: IPC endpoint 'ipc:///tmp/openkore-ai.sock' is not supported on Windows
```

**Cause**: Trying to use Unix IPC sockets on Windows

**Solution**:
```bash
# In ai_sidecar/.env
# Remove or comment out this line:
# AI_ZMQ_ENDPOINT=ipc:///tmp/openkore-ai.sock

# Let system auto-detect (will use TCP)
# OR explicitly set to TCP:
AI_ZMQ_ENDPOINT=tcp://127.0.0.1:5555
```

**Why This Happens**:
- Windows does **NOT** support Unix domain sockets
- IPC (`ipc://`) protocol is Unix-specific
- Windows must use TCP (`tcp://`) protocol

---

### Issue 9: High CPU Usage

**Symptom**: Python process using >50% CPU constantly

**Causes & Solutions**:

**Cause 1: Too-fast tick rate**
```bash
# In .env, increase interval:
AI_TICK_INTERVAL_MS=200  # Reduce from 100ms to 200ms
```

**Cause 2: Debug mode enabled**
```bash
# Disable debug mode:
AI_DEBUG=false
AI_LOG_LEVEL=INFO  # Not DEBUG
```

**Cause 3: LLM mode with high rate**
```bash
# Add rate limiting:
API_RATE_LIMIT_PER_MINUTE=30  # Reduce from 60
```

**Check CPU Usage**:
```powershell
# Monitor Python processes
Get-Process python | Select-Object Id,ProcessName,CPU,WorkingSet | Format-Table
```

---

### Issue 10: Memory Leaks / High RAM Usage

**Symptom**: AI Sidecar RAM usage growing over time

**Solutions**:

```bash
# In .env, reduce memory limits:
AI_MEMORY_WORKING_MAX_SIZE=500        # Reduce from 1000
AI_TICK_STATE_HISTORY_SIZE=50         # Reduce from 100
AI_MAX_MEMORY_MB=256                  # Set stricter limit
```

**Monitor Memory**:
```powershell
# Check memory usage
Get-Process python | 
  Where-Object {$_.Path -like "*openkore*"} |
  Select-Object Id,ProcessName,@{N='MemoryMB';E={[math]::Round($_.WorkingSet/1MB,2)}}
```

---

## 🚀 Performance Optimization

### TCP Socket Optimization on Windows

While TCP has slightly higher latency than IPC, you can optimize it:

#### 1. Use Loopback Address

```bash
# Fastest TCP option on Windows
AI_ZMQ_ENDPOINT=tcp://127.0.0.1:5555

# Avoid using computer name or external IP for local connections
# ❌ SLOW: tcp://MyComputerName:5555
# ✅ FAST: tcp://127.0.0.1:5555
```

#### 2. TCP Configuration

```bash
# Adjust timeouts for responsiveness vs reliability
AI_ZMQ_RECV_TIMEOUT_MS=50   # Faster responses
AI_ZMQ_SEND_TIMEOUT_MS=50   # Faster sends

# Or increase for stability
AI_ZMQ_RECV_TIMEOUT_MS=200  # More reliable
AI_ZMQ_SEND_TIMEOUT_MS=200
```

#### 3. Windows Network Optimization

**Disable Nagle's Algorithm** (reduces latency):

ZeroMQ already handles this, but you can verify:

```powershell
# Check TCP settings
Get-NetTCPSetting | Format-Table
```

### CPU Backend Optimization

```bash
# Optimal settings for CPU mode on Windows:
AI_TICK_INTERVAL_MS=100              # 10 ticks/second
AI_DECISION_MAX_ACTIONS_PER_TICK=5   # Balanced
AI_MAX_MEMORY_MB=512                 # Adequate for CPU mode
```

### GPU Mode on Windows

**Requirements**:
- NVIDIA GeForce GTX 1060 or better
- 6GB+ VRAM
- CUDA Toolkit 12.x installed

**Installation**:

1. **Install CUDA Toolkit**:
   - Download from [NVIDIA CUDA Downloads](https://developer.nvidia.com/cuda-downloads)
   - Select Windows → x86_64 → Version 12.x
   - Run installer with default options

2. **Verify CUDA Installation**:
   ```powershell
   # Check CUDA version
   nvcc --version
   
   # Check GPU is visible
   nvidia-smi
   ```

3. **Install PyTorch with CUDA** (if using GPU mode):
   ```powershell
   # Activate virtual environment
   .\.venv\Scripts\Activate.ps1
   
   # Install PyTorch with CUDA support
   pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
   ```

4. **Configure GPU Mode**:
   ```bash
   # In .env
   COMPUTE_BACKEND=gpu
   AI_DECISION_ENGINE_TYPE=ml
   AI_MAX_MEMORY_MB=2048  # Higher for GPU mode
   ```

**Verify GPU Detection**:
```powershell
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}'); print(f'GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'None'}')"
```

---

## 🔷 WSL Users

### WSL 1 vs WSL 2

The system automatically detects your WSL version and configures accordingly.

#### WSL 1 (Older)

**Characteristics**:
- Limited Linux kernel
- IPC sockets may not work reliably
- **Auto-configured to use TCP**

**Recommended Setup**:
```bash
# Let auto-detection handle it
# System will use: tcp://127.0.0.1:5555
```

#### WSL 2 (Recommended)

**Characteristics**:
- Full Linux kernel
- Complete IPC support
- **Auto-configured to use IPC**

**Recommended Setup**:
```bash
# Let auto-detection handle it  
# System will use: ipc:///tmp/openkore-ai.sock
```

### Check Your WSL Version

**From Windows PowerShell**:
```powershell
wsl.exe -l -v
```

**Output Example**:
```
  NAME            STATE           VERSION
* Ubuntu-22.04    Running         2
```

### Upgrade WSL 1 to WSL 2

```powershell
# Set WSL 2 as default
wsl --set-default-version 2

# Convert existing distro to WSL 2
wsl --set-version Ubuntu-22.04 2

# Restart WSL
wsl --shutdown
wsl
```

### Cross-Platform Communication (WSL ↔ Windows)

If running AI Sidecar in WSL and OpenKore in Windows (or vice versa):

**Option 1: Both Use TCP** (Easier)
```bash
# WSL side (.env):
AI_ZMQ_ENDPOINT=tcp://0.0.0.0:5555

# Windows side (AI_Bridge.txt):
AI_Bridge_address tcp://localhost:5555
```

**Option 2: Use WSL IP** (Advanced)
```bash
# Find WSL IP address:
wsl hostname -I

# Windows side (AI_Bridge.txt):
AI_Bridge_address tcp://172.xx.xx.xx:5555
```

### WSL File System Performance

```bash
# ⚠️ IMPORTANT: Store project in WSL filesystem, not Windows
# ❌ SLOW:  /mnt/c/Users/YourName/openkore-AI
# ✅ FAST:  ~/openkore-AI or /home/yourname/openkore-AI

# Check current location
pwd

# If in /mnt/c, move to WSL filesystem:
cp -r /mnt/c/Users/YourName/openkore-AI ~/openkore-AI
cd ~/openkore-AI
```

---

## 🔬 Advanced Topics

### Running Multiple Instances

To run multiple bots on the same Windows machine:

**Bot 1** (Port 5555):
```bash
# bot1/.env
AI_ZMQ_ENDPOINT=tcp://127.0.0.1:5555
```

**Bot 2** (Port 5556):
```bash
# bot2/.env
AI_ZMQ_ENDPOINT=tcp://127.0.0.1:5556
```

**Each needs**:
- Separate OpenKore directory
- Separate AI Sidecar process
- Different TCP port
- Matching Perl configuration

### Remote Access Setup

**⚠️ WARNING**: Only do this if you understand the security implications!

**AI Sidecar on Windows Server**:
```bash
# Listen on all interfaces
AI_ZMQ_ENDPOINT=tcp://0.0.0.0:5555
```

**Client on Another Machine**:
```perl
# plugins/AI_Bridge/AI_Bridge.txt
AI_Bridge_address tcp://192.168.1.100:5555
```

**Firewall Configuration**:
```powershell
# Allow inbound connections on port 5555
New-NetFirewallRule -DisplayName "OpenKore AI Remote Access" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort 5555 `
  -Action Allow `
  -Profile Private
```

### Using Windows Services

Run AI Sidecar as a Windows service for auto-start:

**Using NSSM** (Non-Sucking Service Manager):

1. **Download NSSM**: [nssm.cc/download](https://nssm.cc/download)

2. **Install Service**:
   ```powershell
   # Extract nssm.exe and run as admin:
   .\nssm.exe install OpenKoreAI "C:\path\to\.venv\Scripts\python.exe" "C:\path\to\ai_sidecar\main.py"
   
   # Configure service
   .\nssm.exe set OpenKoreAI AppDirectory "C:\path\to\openkore-AI\ai_sidecar"
   .\nssm.exe set OpenKoreAI AppEnvironmentExtra "VIRTUAL_ENV=C:\path\to\.venv"
   
   # Start service
   .\nssm.exe start OpenKoreAI
   ```

3. **Manage Service**:
   ```powershell
   # Check status
   Get-Service OpenKoreAI
   
   # Start/Stop
   Start-Service OpenKoreAI
   Stop-Service OpenKoreAI
   
   # Remove service
   .\nssm.exe remove OpenKoreAI confirm
   ```

### Performance Monitoring

**Real-Time Monitoring**:
```powershell
# Monitor CPU and Memory
while ($true) {
  Get-Process python | 
    Where-Object {$_.Path -like "*openkore*"} |
    Select-Object ProcessName,
                  @{N='CPU%';E={$_.CPU}},
                  @{N='MemoryMB';E={[math]::Round($_.WorkingSet/1MB,2)}} |
    Format-Table
  Start-Sleep -Seconds 2
  Clear-Host
}
```

**Performance Counters**:
```powershell
# Get detailed performance data
Get-Counter '\Process(python*)\% Processor Time','\Process(python*)\Working Set'
```

### Task Scheduler Automation

**Auto-start AI Sidecar on login**:

1. Search Windows: "Task Scheduler"
2. Click "Create Basic Task"
3. Name: "OpenKore AI Sidecar"
4. Trigger: "When I log on"
5. Action: "Start a program"
6. Program: `C:\path\to\.venv\Scripts\python.exe`
7. Arguments: `main.py`
8. Start in: `C:\path\to\openkore-AI\ai_sidecar`
9. Finish

---

## 💡 FAQ

### Q: Can I use IPC sockets on Windows?

**A**: No. Windows does not support Unix domain sockets. The system automatically uses TCP, which works perfectly with minimal overhead (1-2ms vs <1ms for IPC).

### Q: Is TCP slower than IPC?

**A**: Slightly (1-2ms vs <1ms), but this is negligible for gameplay. You won't notice the difference.

### Q: Why does the guide mention IPC if Windows can't use it?

**A**: The AI Sidecar is cross-platform. IPC examples are for Linux/macOS users. Windows sections clearly indicate TCP-only.

### Q: Can I run AI Sidecar on Windows and OpenKore on WSL?

**A**: Yes! Use TCP endpoint on both sides:
```bash
# Windows side (.env):
AI_ZMQ_ENDPOINT=tcp://0.0.0.0:5555

# WSL side (AI_Bridge.txt):
AI_Bridge_address tcp://localhost:5555
```

### Q: Does automatic detection work in Docker on Windows?

**A**: Yes, but Docker on Windows typically runs Linux containers, which support IPC. Use volume mounts for IPC sockets.

### Q: What if I get "Cannot bind to endpoint" error?

**A**: Port 5555 is in use. Either:
1. Stop the other process using the port
2. Use a different port (edit `.env` and `AI_Bridge.txt`)

### Q: Do I need special Windows features enabled?

**A**: No. Works on standard Windows 10/11 with no special features required.

### Q: Can I use Windows Subsystem for Linux (WSL)?

**A**: Yes! WSL 2 is actually preferred for better Linux compatibility. See [WSL Users](#-wsl-users) section.

### Q: Will this work on Windows Server?

**A**: Yes. Same installation process applies to Windows Server 2019, 2022, and later.

### Q: Can I use pyzmq installed system-wide instead of venv?

**A**: Not recommended. Virtual environments prevent conflicts and ensure consistent behavior. But yes, it will work if configured correctly.

---

## 📚 Additional Resources

### Windows-Specific Documentation

- **Microsoft Python Docs**: [docs.microsoft.com/python](https://docs.microsoft.com/python)
- **Windows Terminal**: [github.com/microsoft/terminal](https://github.com/microsoft/terminal)
- **WSL Documentation**: [docs.microsoft.com/wsl](https://docs.microsoft.com/windows/wsl/)

### OpenKore AI Documentation

- **Main README**: [`README.md`](../README.md)
- **ZMQ Troubleshooting**: [`docs/ZMQ_TROUBLESHOOTING.md`](ZMQ_TROUBLESHOOTING.md)
- **Architecture Details**: [`docs/CROSS_PLATFORM_ZMQ_ARCHITECTURE.md`](CROSS_PLATFORM_ZMQ_ARCHITECTURE.md)
- **Bridge Integration**: [`BRIDGE_INTEGRATION_CHECKLIST.md`](../BRIDGE_INTEGRATION_CHECKLIST.md)

### Community Support

- **Discord**: [discord.com/invite/hdAhPM6](https://discord.com/invite/hdAhPM6)
- **Forum**: [forums.openkore.com](https://forums.openkore.com/)
- **GitHub Issues**: [github.com/OpenKore/openkore/issues](https://github.com/OpenKore/openkore/issues)

---

## 📝 Quick Reference

### Common PowerShell Commands

```powershell
# Navigate to project
cd C:\path\to\openkore-AI

# Activate virtual environment
.\.venv\Scripts\Activate.ps1

# Start AI Sidecar
cd ai_sidecar
python main.py

# Check running processes
Get-Process python

# Check port usage
Get-NetTCPConnection -LocalPort 5555

# Kill process by port
Stop-Process -Id (Get-NetTCPConnection -LocalPort 5555).OwningProcess
```

### Configuration File Locations

| File | Path | Purpose |
|------|------|---------|
| Python Config | `ai_sidecar\.env` | AI Sidecar settings |
| Perl Config | `plugins\AI_Bridge\AI_Bridge.txt` | OpenKore bridge settings |
| Server Config | `control\config.txt` | OpenKore server settings |
| Logs | `ai_sidecar\logs\` | AI Sidecar log files |

### Default Values (Windows)

| Setting | Value | Notes |
|---------|-------|-------|
| **Endpoint** | `tcp://127.0.0.1:5555` | Auto-detected |
| **IPC Support** | ❌ Disabled | Not available on Windows |
| **Platform Name** | `Windows` | Auto-detected |
| **Transport** | TCP | Only option |
| **Latency** | 1-2ms | Acceptable for gameplay |

---

## 🔄 Update & Maintenance

### Updating OpenKore AI

```powershell
# Navigate to project
cd C:\path\to\openkore-AI

# Pull latest changes
git pull origin main

# Activate virtual environment
.\.venv\Scripts\Activate.ps1

# Update dependencies
pip install -e . --upgrade

# Restart AI Sidecar
```

### Backup Configuration

```powershell
# Backup your .env file before updates
Copy-Item ai_sidecar\.env ai_sidecar\.env.backup

# Restore if needed
Copy-Item ai_sidecar\.env.backup ai_sidecar\.env
```

### Clean Reinstall

```powershell
# Remove virtual environment
Remove-Item -Recurse -Force .venv

# Recreate virtual environment
python -m venv .venv
.\.venv\Scripts\Activate.ps1

# Reinstall dependencies
pip install --upgrade pip
pip install -e .
```

---

## 🆘 Getting Help

### Before Asking for Help

1. ✅ Check this guide thoroughly
2. ✅ Check [`docs/ZMQ_TROUBLESHOOTING.md`](ZMQ_TROUBLESHOOTING.md)
3. ✅ Review error messages carefully
4. ✅ Try basic troubleshooting steps
5. ✅ Check if issue is in GitHub Issues

### How to Report Issues

When reporting Windows-specific issues, include:

```powershell
# Run this and include output:
python --version
pip list | Select-String "zmq|pydantic|structlog"
$PSVersionTable.PSVersion

# Platform detection output:
cd ai_sidecar
python -c "from ai_sidecar.utils.platform import detect_platform; print(detect_platform())"

# Windows version:
Get-ComputerInfo | Select-Object WindowsProductName,WindowsVersion,OsArchitecture
```

### Useful Diagnostic Commands

```powershell
# Check what's using port 5555
Get-NetTCPConnection -LocalPort 5555 -ErrorAction SilentlyContinue |
  ForEach-Object { Get-Process -Id $_.OwningProcess }

# Check AI Sidecar process details
Get-Process python | Where-Object {$_.Path -like "*openkore*"} |
  Select-Object Id,ProcessName,StartTime,CPU,@{N='MemoryMB';E={[math]::Round($_.WorkingSet/1MB,2)}}

# View recent logs
Get-Content ai_sidecar\logs\ai_sidecar.log -Tail 50

# Check Python path and environment
Get-Command python | Select-Object Source
$env:PYTHONPATH
```

---

## ✅ Windows Setup Checklist

Use this checklist to verify your installation:

**Prerequisites**:
- [ ] Windows 10 (1903+) or Windows 11 installed
- [ ] Python 3.11+ installed with "Add to PATH" checked
- [ ] Git for Windows installed
- [ ] Visual C++ Redistributable installed
- [ ] Perl installed (for OpenKore)

**Installation**:
- [ ] Repository cloned to Windows drive
- [ ] Virtual environment created (`.venv/`)
- [ ] Virtual environment activated (shows `(.venv)`)
- [ ] Dependencies installed via `pip install -e .`
- [ ] `.env` file created from `.env.example`

**Configuration**:
- [ ] Platform detection shows "Windows"
- [ ] Default endpoint is TCP (not IPC)
- [ ] No IPC socket errors
- [ ] Port 5555 available or alternative configured
- [ ] Perl side matches Python side endpoint

**Verification**:
- [ ] AI Sidecar starts without errors
- [ ] Binds to `tcp://127.0.0.1:5555` successfully
- [ ] OpenKore connects to AI Sidecar
- [ ] Messages exchange successfully
- [ ] No firewall blocks
- [ ] Bot responds to game events

**Performance** (Optional):
- [ ] CPU usage <25% average
- [ ] Memory usage <1GB (CPU mode)
- [ ] Latency <50ms average
- [ ] No timeout errors

If all items are checked, your Windows installation is complete! 🎉

---

**💡 Pro Tips for Windows Users**:
- Use Windows Terminal for better experience
- Keep project on SSD for better performance
- Disable antivirus scanning for project folder
- Use WSL 2 for best Linux compatibility
- TCP is perfectly fine - don't worry about IPC!

---

*Last Updated: December 6, 2025*  
*Maintained by: OpenKore AI Team*  
*For: Windows 10/11 Users*