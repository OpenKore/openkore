# 🪟 Windows Testing Checklist for install.bat

This document provides a comprehensive testing guide for the [`install.bat`](install.bat) automated installation script on Windows systems.

---

## 📋 Table of Contents

- [Prerequisites](#-prerequisites)
- [Pre-Testing Setup](#-pre-testing-setup)
- [Test Scenarios](#-test-scenarios)
  - [Test 1: Fresh Installation](#test-1-fresh-installation)
  - [Test 2: Verification Tests](#test-2-verification-tests)
  - [Test 3: Force Reinstall](#test-3-force-reinstall)
  - [Test 4: Help Command](#test-4-help-command)
  - [Test 5: Error Scenarios](#test-5-error-scenarios-optional)
- [Success Criteria Checklist](#-success-criteria-checklist)
- [Reporting Results](#-reporting-results)
- [Common Issues and Solutions](#-common-issues-and-solutions)
- [Next Steps After Successful Testing](#-next-steps-after-successful-testing)

---

## ✅ Prerequisites

Before testing the installation script, ensure the following are installed and configured:

### Required Software

- [ ] **Windows 10** or **Windows 11** (64-bit recommended)
- [ ] **Python 3.10+** installed from [python.org](https://www.python.org/downloads/)
  - ⚠️ **CRITICAL**: Must check "Add Python to PATH" during installation
- [ ] **Internet connection** (for downloading packages)

### Verify Python Installation

Open Command Prompt and run:

```cmd
py --version
```

**Expected output:**
```
Python 3.10.x (or higher)
```

**Alternative commands to try:**
```cmd
python --version
python3 --version
```

### Verify pip Installation

```cmd
py -m pip --version
```

**Expected output:**
```
pip 24.x.x from C:\...\site-packages\pip (python 3.10)
```

---

## 🔧 Pre-Testing Setup

### 1. Open Command Prompt

**As Regular User (NOT Administrator):**

**Method 1 - Start Menu:**
- Press `Windows + R`
- Type `cmd`
- Press `Enter`

**Method 2 - Search:**
- Press `Windows` key
- Type "Command Prompt"
- Click on "Command Prompt" (not "Run as Administrator")

**Method 3 - PowerShell (Alternative):**
- Press `Windows + X`
- Select "Windows PowerShell" or "Terminal"

### 2. Navigate to Project Directory

```cmd
cd C:\path\to\ai-mmorpg-world\openkore-AI
```

Replace `C:\path\to\ai-mmorpg-world` with your actual project path.

**Verify you're in the correct directory:**
```cmd
dir
```

You should see files including:
- `install.bat`
- `pyproject.toml`
- `INSTALL.md`

### 3. Check Current State

**Check if virtual environment already exists:**
```cmd
dir ai_sidecar\.venv
```

If it exists and you want a fresh test:
```cmd
rmdir /s /q ai_sidecar\.venv
```

---

## 🧪 Test Scenarios

---

## Test 1: Fresh Installation

This test verifies the standard installation process from scratch.

### Pre-Test Cleanup

```cmd
rmdir /s /q ai_sidecar\.venv
```

### Test Steps

#### Step 1.1: Run Installation Script

```cmd
install.bat
```

- [ ] Script starts without errors
- [ ] Clear screen is displayed
- [ ] Welcome header is shown

#### Step 1.2: Verify Step-by-Step Progress

Watch for each step to complete successfully:

**[1/7] Checking Python installation...**
- [ ] Displays: `[OK] Python found: py -3` (or `python` or `python3`)

**[2/7] Verifying Python version...**
- [ ] Displays: `[OK] Python X.X.X meets minimum requirement (3.10)`

**[3/7] Checking pip availability...**
- [ ] Displays: `[OK] pip X.X.X is available`

**[4/7] Setting up virtual environment...**
- [ ] Displays: `[OK] Virtual environment ready at: ...\ai_sidecar\.venv`
- [ ] Takes 5-15 seconds

**[5/7] Upgrading pip, setuptools, and wheel...**
- [ ] Displays: `Upgrading packages...`
- [ ] Displays: `[OK] pip upgraded to version X.X.X`
- [ ] Takes 10-30 seconds

**[6/7] Installing dependencies...**
- [ ] Displays: `Installing packages (this may take a few minutes)...`
- [ ] Takes 1-5 minutes depending on internet speed
- [ ] Displays: `[OK] Dependencies installed successfully`

**[7/7] Verifying installation...**
- [ ] Displays: `[OK] Installation verified successfully`

#### Step 1.3: Check Completion Message

- [ ] "Installation Complete!" header is displayed
- [ ] Next steps are listed (4 sections)
- [ ] Documentation paths are shown
- [ ] Tips section is displayed
- [ ] Activation reminder is shown
- [ ] Displays: `Press any key to continue . . .`

### Expected Output Summary

```
============================================================================
   OpenKore AI Sidecar - Windows Installation
============================================================================

Project:  God-Tier AI Sidecar for OpenKore
Version:  3.0.0
Location: C:\...\openkore-AI\

[1/7] Checking Python installation...
[OK] Python found: py -3

[2/7] Verifying Python version (minimum 3.10)...
[OK] Python 3.10.x meets minimum requirement (3.10)

[3/7] Checking pip availability...
[OK] pip 24.x.x is available

[4/7] Setting up virtual environment...
[OK] Virtual environment ready at: ...\ai_sidecar\.venv

[5/7] Upgrading pip, setuptools, and wheel...
   Upgrading packages...
[OK] pip upgraded to version 24.x.x

[6/7] Installing dependencies...
   Installing packages (this may take a few minutes)...
[OK] Dependencies installed successfully

[7/7] Verifying installation...
[OK] Installation verified successfully

============================================================================
   Installation Complete!
============================================================================

[OK] AI Sidecar has been successfully installed!

... (next steps and documentation)
```

---

## Test 2: Verification Tests

These tests verify the installation worked correctly.

### Test 2.1: Virtual Environment Structure

```cmd
dir ai_sidecar\.venv
```

**Expected directories/files:**
- [ ] `Scripts\` directory exists
- [ ] `Lib\` directory exists
- [ ] `Include\` directory exists
- [ ] `pyvenv.cfg` file exists

### Test 2.2: Activation Script Exists

```cmd
dir ai_sidecar\.venv\Scripts\activate.bat
```

- [ ] File exists and shows size > 0 bytes

### Test 2.3: Python Executable in Virtual Environment

```cmd
ai_sidecar\.venv\Scripts\python.exe --version
```

**Expected output:**
- [ ] Shows Python version 3.10.x or higher

### Test 2.4: Activate Virtual Environment

```cmd
ai_sidecar\.venv\Scripts\activate.bat
```

**Expected changes:**
- [ ] Command prompt changes to show `(.venv)` prefix
- [ ] Example: `(.venv) C:\...\openkore-AI>`

### Test 2.5: Test Module Import

```cmd
python -c "import ai_sidecar"
```

- [ ] No output = Success ✅
- [ ] No errors displayed

### Test 2.6: Test Core Dependencies

```cmd
python -c "import zmq, pydantic, structlog, aiofiles"
```

- [ ] No output = Success ✅
- [ ] No errors displayed

### Test 2.7: Check Package Version (if available)

```cmd
python -c "import ai_sidecar; print(getattr(ai_sidecar, '__version__', 'version not set'))"
```

- [ ] Shows version number or "version not set" (both are acceptable)

### Test 2.8: List Installed Packages

```cmd
pip list
```

**Should include:**
- [ ] `ai-sidecar` (editable)
- [ ] `pyzmq`
- [ ] `pydantic`
- [ ] `structlog`
- [ ] `aiofiles`

### Test 2.9: Verify Editable Installation

```cmd
pip show ai-sidecar
```

**Expected output includes:**
- [ ] Name: ai-sidecar
- [ ] Version: (some version)
- [ ] Location: C:\...\openkore-AI (project directory)
- [ ] `Editable project location: ...`

### Test 2.10: Deactivate Virtual Environment

```cmd
deactivate
```

- [ ] Command prompt prefix `(.venv)` disappears

---

## Test 3: Force Reinstall

This test verifies the `--force` flag works correctly.

### Test 3.1: Run with Force Flag

```cmd
install.bat --force
```

**Expected behavior:**

**Force warning displayed:**
- [ ] Shows: `[!] Force install mode enabled - will recreate virtual environment`

**At step [4/7]:**
- [ ] Shows: `[WARNING] Virtual environment exists. Removing due to --force flag...`
- [ ] Virtual environment is removed
- [ ] New virtual environment is created

**All other steps:**
- [ ] Complete successfully as in Test 1

### Test 3.2: Verify Recreation

After installation completes:

```cmd
dir ai_sidecar\.venv
```

- [ ] Directory exists (freshly created)
- [ ] Timestamp shows recent creation time

---

## Test 4: Help Command

This test verifies the help documentation is displayed correctly.

### Test 4.1: Standard Help Flag

```cmd
install.bat --help
```

**Expected output sections:**

- [ ] **USAGE** section with syntax
- [ ] **OPTIONS** section listing all flags:
  - `/force, --force`
  - `/verbose, --verbose`
  - `/?, --help, /h, -h`
- [ ] **DESCRIPTION** section with 6 installation steps
- [ ] **EXAMPLES** section with 3 examples
- [ ] **REQUIREMENTS** section
- [ ] Reference to INSTALL.md

### Test 4.2: Alternative Help Flags

Test each variant:

```cmd
install.bat /?
install.bat /h
install.bat -h
```

- [ ] All variants show the same help output
- [ ] Script exits after displaying help (no installation starts)

---

## Test 5: Error Scenarios (Optional)

These tests verify proper error handling.

### Test 5.1: Python Not in PATH

**Setup (temporarily break Python):**
1. Note your current PATH
2. Temporarily rename Python directory or modify PATH

**Test:**
```cmd
install.bat
```

**Expected output:**
- [ ] Shows: `[ERROR] Python is not installed or not in PATH!`
- [ ] Provides download link: https://www.python.org/downloads/
- [ ] Reminds to check "Add Python to PATH"
- [ ] Exits with error code 1

**Cleanup:** Restore your PATH

### Test 5.2: Wrong Python Version (if testable)

If you have Python 3.9 or older available:

```cmd
install.bat
```

**Expected output:**
- [ ] Shows: `[ERROR] Python version too old!`
- [ ] Shows found version vs required version
- [ ] Provides upgrade instructions
- [ ] Exits with error code 1

### Test 5.3: Running from Wrong Directory

```cmd
cd ..
install.bat
```

**Expected output:**
- [ ] Shows: `[ERROR] pyproject.toml not found!`
- [ ] Shows: `Please run this script from the openkore-AI directory`
- [ ] Shows current directory
- [ ] Exits with error code 1

### Test 5.4: Verbose Mode

```cmd
install.bat --verbose
```

**Expected additional output:**
- [ ] Shows: `[i] Verbose mode enabled`
- [ ] Shows `[VERBOSE]` prefixed messages for each step
- [ ] Shows detailed version information
- [ ] Shows pip/package installation progress in real-time
- [ ] Installation still completes successfully

### Test 5.5: Combined Flags

```cmd
install.bat --force --verbose
```

- [ ] Both force and verbose mode messages are shown
- [ ] Installation proceeds with both modes active

---

## ✅ Success Criteria Checklist

Mark each item as you verify it:

### Installation Process
- [ ] Script runs without requiring Administrator privileges
- [ ] All 7 installation steps complete successfully
- [ ] No error messages are displayed during installation
- [ ] Installation completes within reasonable time (< 10 minutes)
- [ ] "Installation Complete!" message is displayed

### Virtual Environment
- [ ] `.venv` directory is created in `ai_sidecar\`
- [ ] Contains `Scripts\`, `Lib\`, and `Include\` directories
- [ ] `activate.bat` script exists and works
- [ ] Python executable exists in `Scripts\` directory
- [ ] Command prompt shows `(.venv)` prefix when activated

### Package Installation
- [ ] `ai_sidecar` module can be imported
- [ ] Core dependencies can be imported (zmq, pydantic, structlog, aiofiles)
- [ ] `pip list` shows ai-sidecar as editable installation
- [ ] `pip show ai-sidecar` shows correct location

### Command-Line Options
- [ ] `--help` displays complete help information
- [ ] `--force` removes and recreates virtual environment
- [ ] `--verbose` shows detailed output
- [ ] Multiple flags can be combined

### Error Handling
- [ ] Missing Python is detected with helpful error
- [ ] Wrong directory is detected with helpful error
- [ ] Wrong Python version is detected (if testable)
- [ ] All errors show actionable solutions

### Documentation
- [ ] Completion message shows correct activation path
- [ ] Next steps are clearly listed
- [ ] Documentation paths are shown
- [ ] Tips are helpful and relevant

---

## 📊 Reporting Results

### Success Report Template

If all tests pass, report:

```markdown
## ✅ Windows Testing Report - SUCCESS

**Test Environment:**
- Windows Version: Windows 11 Pro (or your version)
- Python Version: 3.10.11 (or your version)
- pip Version: 24.0 (or your version)
- Test Date: 2024-12-04

**Tests Completed:**
- [x] Test 1: Fresh Installation - PASSED
- [x] Test 2: Verification Tests - PASSED
- [x] Test 3: Force Reinstall - PASSED
- [x] Test 4: Help Command - PASSED
- [x] Test 5: Error Scenarios - PASSED

**Summary:**
All installation tests completed successfully. The install.bat script works
as expected on Windows 11. Installation takes approximately X minutes on
a standard internet connection.

**Additional Notes:**
(Any observations or recommendations)
```

### Failure Report Template

If any test fails, report:

```markdown
## ❌ Windows Testing Report - ISSUES FOUND

**Test Environment:**
- Windows Version: Windows 10 Home (or your version)
- Python Version: 3.10.11 (or your version)
- pip Version: 24.0 (or your version)
- Test Date: 2024-12-04

**Failed Tests:**

### Test X: [Test Name] - FAILED

**Issue Description:**
Clear description of what went wrong

**Expected Behavior:**
What should have happened

**Actual Behavior:**
What actually happened

**Error Messages:**
```
(Paste any error messages here)
```

**Screenshots:**
(Attach screenshots if applicable)

**Steps to Reproduce:**
1. Step 1
2. Step 2
3. ...

**System Information:**
- Python path: C:\...
- Virtual environment location: C:\...
- Any relevant environment variables

**Possible Cause:**
(If you can identify it)
```

---

## ⚠️ Common Issues and Solutions

### Issue 1: Python Not Found

**Symptoms:**
```
[ERROR] Python is not installed or not in PATH!
```

**Solutions:**

1. **Verify Python installation:**
   ```cmd
   where python
   where py
   ```

2. **Add Python to PATH manually:**
   - Open "Edit system environment variables"
   - Click "Environment Variables"
   - Under "User variables", select "Path"
   - Add Python installation directory (e.g., `C:\Users\YourName\AppData\Local\Programs\Python\Python310`)
   - Add Scripts directory (e.g., `C:\Users\YourName\AppData\Local\Programs\Python\Python310\Scripts`)

3. **Reinstall Python:**
   - Download from [python.org](https://www.python.org/downloads/)
   - **CHECK** "Add Python to PATH" during installation

### Issue 2: Permission Errors

**Symptoms:**
```
[ERROR] Failed to create virtual environment.
... Insufficient permissions
```

**Solutions:**

1. **Don't run as Administrator** (counterintuitive but correct)
2. **Check directory permissions:**
   - Right-click project folder
   - Properties → Security
   - Ensure your user has "Full control"

3. **Disable antivirus temporarily** (some antivirus software blocks venv creation)

4. **Try a different directory** (avoid system-protected folders)

### Issue 3: Virtual Environment Activation Issues

**Symptoms:**
```
'activate' is not recognized as an internal or external command
```

**Solutions:**

1. **Use full path:**
   ```cmd
   ai_sidecar\.venv\Scripts\activate.bat
   ```

2. **Check if file exists:**
   ```cmd
   dir ai_sidecar\.venv\Scripts\activate.bat
   ```

3. **In PowerShell, use:**
   ```powershell
   ai_sidecar\.venv\Scripts\Activate.ps1
   ```

4. **Enable scripts in PowerShell (if needed):**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

### Issue 4: Module Not Found Errors

**Symptoms:**
```
ModuleNotFoundError: No module named 'ai_sidecar'
```

**Solutions:**

1. **Ensure virtual environment is activated:**
   - Look for `(.venv)` prefix in command prompt

2. **Verify editable installation:**
   ```cmd
   pip show ai-sidecar
   ```

3. **Reinstall with force:**
   ```cmd
   install.bat --force
   ```

4. **Check Python is from venv:**
   ```cmd
   where python
   ```
   Should show path in `.venv\Scripts\`

### Issue 5: Network/Download Errors

**Symptoms:**
```
[ERROR] Failed to install dependencies.
... Network connectivity issues
```

**Solutions:**

1. **Check internet connection**

2. **Use verbose mode to see specific errors:**
   ```cmd
   install.bat --verbose
   ```

3. **Try with different network** (some corporate networks block pip)

4. **Configure pip proxy (if behind corporate firewall):**
   ```cmd
   set HTTP_PROXY=http://proxy.example.com:8080
   set HTTPS_PROXY=http://proxy.example.com:8080
   install.bat
   ```

5. **Temporarily disable VPN** (some VPNs interfere with pip)

### Issue 6: Missing Build Tools

**Symptoms:**
```
error: Microsoft Visual C++ 14.0 or greater is required
```

**Solutions:**

1. **Install Visual Studio Build Tools:**
   - Download from [visualstudio.microsoft.com](https://visualstudio.microsoft.com/downloads/)
   - Select "Desktop development with C++"

2. **Or install full Visual Studio Community Edition** (free)

3. **Alternative: Use pre-built wheels:**
   - Most packages should have pre-built wheels for Windows
   - If issue persists, report which specific package is failing

### Issue 7: Long Path Issues (Windows-specific)

**Symptoms:**
```
OSError: [WinError 206] The filename or extension is too long
```

**Solutions:**

1. **Enable long paths in Windows 10/11:**
   - Open Registry Editor (regedit)
   - Navigate to: `HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem`
   - Set `LongPathsEnabled` to `1`

2. **Or move project to shorter path:**
   ```cmd
   C:\dev\ai-mmorpg-world\openkore-AI
   ```

---

## 🚀 Next Steps After Successful Testing

Once all tests pass, you're ready to use the AI Sidecar!

### 1. Activate Virtual Environment

Always activate before use:

```cmd
ai_sidecar\.venv\Scripts\activate.bat
```

Verify activation:
```cmd
where python
```
Should show: `...\ai_sidecar\.venv\Scripts\python.exe`

### 2. Configure Environment (Optional)

If `.env.example` exists:

```cmd
copy .env.example .env
notepad .env
```

Edit configuration as needed.

### 3. Run the AI Sidecar

```cmd
cd ai_sidecar
python main.py
```

**Or if using a different entry point:**
```cmd
python -m ai_sidecar
```

### 4. Start OpenKore (In Another Terminal)

```cmd
cd C:\path\to\ai-mmorpg-world\openkore-AI
start.exe
```

### 5. Verify Communication

Check that AI Sidecar and OpenKore are communicating:
- AI Sidecar should show connection logs
- OpenKore should show AI Sidecar status

### 6. Daily Usage

**Each time you want to use the AI Sidecar:**

1. Open Command Prompt
2. Navigate to project: `cd C:\path\to\openkore-AI`
3. Activate venv: `ai_sidecar\.venv\Scripts\activate.bat`
4. Run: `cd ai_sidecar && python main.py`

### 7. Updating Dependencies

If you need to update packages:

```cmd
REM Activate virtual environment first
ai_sidecar\.venv\Scripts\activate.bat

REM Update specific package
pip install --upgrade package-name

REM Or update all packages
pip install --upgrade -e .
```

### 8. Troubleshooting

If issues arise:

1. **Check logs** in the project directory
2. **Run with verbose mode:** `install.bat --verbose`
3. **Force reinstall:** `install.bat --force`
4. **Check** [`INSTALL.md`](INSTALL.md) for additional documentation

---

## 📝 Testing Checklist Summary

Print or use this quick reference:

```
📋 QUICK TEST CHECKLIST

Prerequisites:
□ Windows 10/11
□ Python 3.10+
□ pip installed
□ Internet connection

Test 1 - Fresh Install:
□ Run install.bat
□ All 7 steps complete
□ Success message shown

Test 2 - Verification:
□ .venv directory exists
□ activate.bat works
□ import ai_sidecar works
□ pip list shows packages

Test 3 - Force Reinstall:
□ install.bat --force works
□ Recreates environment

Test 4 - Help:
□ install.bat --help works

Test 5 - Error Handling:
□ Wrong directory detected
□ Missing Python detected

Success Criteria:
□ No errors during install
□ Virtual environment created
□ Packages installed
□ Module imports work
□ Documentation shown

All tests passed? ✅ You're ready to use AI Sidecar!
```

---

## 📞 Support

If you encounter issues not covered in this guide:

1. **Check documentation:**
   - [`INSTALL.md`](INSTALL.md) - Detailed installation guide
   - [`README.md`](README.md) - Project overview

2. **Report issues:**
   - Create a GitHub issue with your test results
   - Include Windows version, Python version, and error messages

3. **Community help:**
   - Check existing GitHub issues
   - Ask in project discussions

---

**Document Version:** 1.0.0  
**Last Updated:** 2024-12-04  
**Maintained By:** OpenKore AI Sidecar Team

---

*Happy Testing! 🎉*