@echo off
setlocal enabledelayedexpansion

REM ============================================================================
REM OpenKore AI Sidecar - Automated Installation Script for Windows
REM
REM This script automates the installation of the God-Tier AI Sidecar system.
REM It handles prerequisite checking, virtual environment setup, dependency
REM installation, and verification.
REM
REM Usage:
REM   install.bat [OPTIONS]
REM
REM Options:
REM   /force, --force      Force reinstall even if already installed
REM   /verbose, --verbose  Enable verbose output for debugging
REM   --help, /?, /h, -h   Show this help message
REM
REM Requirements:
REM   - Python 3.10+ with pip and venv
REM   - Internet connection (for downloading packages)
REM
REM Exit Codes:
REM   0 - Success
REM   1 - Python not found or version check failed
REM   2 - pip not found
REM   3 - Virtual environment creation failed
REM   4 - pip upgrade failed
REM   5 - Dependency installation failed
REM   6 - Installation verification failed
REM ============================================================================

REM Configuration
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "VENV_DIR=%SCRIPT_DIR%\ai_sidecar\.venv"
set "PYTHON_MIN_VERSION=3.10"
set "REQUIRED_PYTHON_MAJOR=3"
set "REQUIRED_PYTHON_MINOR=10"

REM Default options
set "FORCE_INSTALL=0"
set "VERBOSE=0"
set "PYTHON_CMD="

REM Parse command-line arguments
:parse_args
if "%~1"=="" goto end_parse_args
if /i "%~1"=="/force" set "FORCE_INSTALL=1"
if /i "%~1"=="--force" set "FORCE_INSTALL=1"
if /i "%~1"=="/verbose" set "VERBOSE=1"
if /i "%~1"=="--verbose" set "VERBOSE=1"
if /i "%~1"=="/?" goto show_help
if /i "%~1"=="--help" goto show_help
if /i "%~1"=="/h" goto show_help
if /i "%~1"=="-h" goto show_help
shift
goto parse_args
:end_parse_args

REM ============================================================================
REM Main Installation Process
REM ============================================================================

cls
echo.
echo ============================================================================
echo    OpenKore AI Sidecar - Windows Installation
echo ============================================================================
echo.
echo Project:  God-Tier AI Sidecar for OpenKore
echo Version:  3.0.0
echo Location: %SCRIPT_DIR%
echo.

if %FORCE_INSTALL%==1 (
    echo [*] Force install mode enabled - will recreate virtual environment
    echo.
)

if %VERBOSE%==1 (
    echo [i] Verbose mode enabled
    echo.
)

REM Check if running from correct directory
if not exist "%SCRIPT_DIR%\pyproject.toml" (
    echo [ERROR] pyproject.toml not found!
    echo.
    echo Please run this script from the openkore-AI directory.
    echo Current directory: %CD%
    echo.
    pause
    exit /b 1
)

REM Step 1: Check Python Installation
echo [1/7] Checking Python installation...
call :check_python
if errorlevel 1 (
    pause
    exit /b 1
)

REM Step 2: Check Python Version
echo [2/7] Verifying Python version ^(minimum %PYTHON_MIN_VERSION%^)...
call :check_python_version
if errorlevel 1 (
    pause
    exit /b 1
)

REM Step 3: Check pip
echo [3/7] Checking pip availability...
call :check_pip
if errorlevel 1 (
    pause
    exit /b 1
)

REM Step 4: Create Virtual Environment
echo [4/7] Setting up virtual environment...
call :setup_venv
if errorlevel 1 (
    pause
    exit /b 1
)

REM Step 5: Upgrade pip
echo [5/7] Upgrading pip, setuptools, and wheel...
call :upgrade_pip
if errorlevel 1 (
    pause
    exit /b 1
)

REM Step 6: Install Dependencies
echo [6/7] Installing dependencies...
call :install_dependencies
if errorlevel 1 (
    pause
    exit /b 1
)

REM Step 7: Verify Installation
echo [7/7] Verifying installation...
call :verify_installation
if errorlevel 1 (
    pause
    exit /b 1
)

REM Success!
call :show_completion_message
pause
exit /b 0

REM ============================================================================
REM Functions
REM ============================================================================

REM ----------------------------------------------------------------------------
REM Function: show_help
REM Shows usage information
REM ----------------------------------------------------------------------------
:show_help
echo.
echo OpenKore AI Sidecar - Windows Installation Script
echo.
echo USAGE:
echo   install.bat [OPTIONS]
echo.
echo OPTIONS:
echo   /force, --force      Force reinstall even if venv exists
echo   /verbose, --verbose  Enable verbose output during installation
echo   --help, /?, /h, -h   Show this help message
echo.
echo DESCRIPTION:
echo   This script automates the installation of the AI Sidecar for OpenKore.
echo   It performs the following steps:
echo.
echo   1. Checks Python version ^(requires 3.10+^)
echo   2. Verifies pip availability
echo   3. Creates a virtual environment in ai_sidecar\.venv\
echo   4. Upgrades pip, setuptools, and wheel
echo   5. Installs the ai-sidecar package in editable mode
echo   6. Verifies the installation
echo.
echo EXAMPLES:
echo   # Standard installation
echo   install.bat
echo.
echo   # Force reinstall with verbose output
echo   install.bat --force --verbose
echo.
echo   # Show help
echo   install.bat --help
echo.
echo REQUIREMENTS:
echo   - Python 3.10 or higher
echo   - pip package manager
echo   - Internet connection
echo.
echo For more information, see: %SCRIPT_DIR%\INSTALL.md
echo.
exit /b 0

REM ----------------------------------------------------------------------------
REM Function: check_python
REM Checks if Python is installed and sets PYTHON_CMD
REM ----------------------------------------------------------------------------
:check_python
set "PYTHON_CMD="

REM Try py launcher first (recommended for Windows)
py --version >nul 2>&1
if %errorlevel% equ 0 (
    set "PYTHON_CMD=py -3"
    if %VERBOSE%==1 echo [VERBOSE] Found Python using 'py' launcher
    goto check_python_success
)

REM Try python command
python --version >nul 2>&1
if %errorlevel% equ 0 (
    set "PYTHON_CMD=python"
    if %VERBOSE%==1 echo [VERBOSE] Found Python using 'python' command
    goto check_python_success
)

REM Try python3 command
python3 --version >nul 2>&1
if %errorlevel% equ 0 (
    set "PYTHON_CMD=python3"
    if %VERBOSE%==1 echo [VERBOSE] Found Python using 'python3' command
    goto check_python_success
)

REM Python not found
echo [ERROR] Python is not installed or not in PATH!
echo.
echo Please install Python %PYTHON_MIN_VERSION% or higher from:
echo   https://www.python.org/downloads/
echo.
echo Make sure to check "Add Python to PATH" during installation.
echo.
exit /b 1

:check_python_success
echo [OK] Python found: %PYTHON_CMD%
exit /b 0

REM ----------------------------------------------------------------------------
REM Function: check_python_version
REM Verifies Python version meets minimum requirements
REM ----------------------------------------------------------------------------
:check_python_version
REM Get Python version
for /f "tokens=2" %%i in ('%PYTHON_CMD% --version 2^>^&1') do set "PYTHON_VERSION=%%i"

if %VERBOSE%==1 echo [VERBOSE] Python version detected: %PYTHON_VERSION%

REM Extract major and minor version numbers
for /f "tokens=1,2 delims=." %%a in ("%PYTHON_VERSION%") do (
    set "PY_MAJOR=%%a"
    set "PY_MINOR=%%b"
)

if %VERBOSE%==1 (
    echo [VERBOSE] Python major version: %PY_MAJOR%
    echo [VERBOSE] Python minor version: %PY_MINOR%
    echo [VERBOSE] Required: %REQUIRED_PYTHON_MAJOR%.%REQUIRED_PYTHON_MINOR%
)

REM Compare versions
if %PY_MAJOR% lss %REQUIRED_PYTHON_MAJOR% goto version_too_old
if %PY_MAJOR% gtr %REQUIRED_PYTHON_MAJOR% goto version_ok
if %PY_MINOR% lss %REQUIRED_PYTHON_MINOR% goto version_too_old

:version_ok
echo [OK] Python %PYTHON_VERSION% meets minimum requirement ^(%PYTHON_MIN_VERSION%^)
exit /b 0

:version_too_old
echo [ERROR] Python version too old!
echo.
echo Found version:    %PYTHON_VERSION%
echo Required version: %PYTHON_MIN_VERSION% or higher
echo.
echo Please upgrade Python from:
echo   https://www.python.org/downloads/
echo.
exit /b 1

REM ----------------------------------------------------------------------------
REM Function: check_pip
REM Checks if pip is available
REM ----------------------------------------------------------------------------
:check_pip
%PYTHON_CMD% -m pip --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] pip is not installed!
    echo.
    echo Please install pip:
    echo   %PYTHON_CMD% -m ensurepip --upgrade
    echo.
    echo Or download get-pip.py from:
    echo   https://bootstrap.pypa.io/get-pip.py
    echo   %PYTHON_CMD% get-pip.py
    echo.
    exit /b 2
)

REM Get pip version
for /f "tokens=2" %%i in ('%PYTHON_CMD% -m pip --version 2^>^&1') do set "PIP_VERSION=%%i"
echo [OK] pip %PIP_VERSION% is available
exit /b 0

REM ----------------------------------------------------------------------------
REM Function: setup_venv
REM Creates or checks virtual environment
REM ----------------------------------------------------------------------------
:setup_venv
REM Check if venv already exists
if exist "%VENV_DIR%\Scripts\python.exe" (
    if %FORCE_INSTALL%==0 (
        echo [WARNING] Virtual environment already exists at: %VENV_DIR%
        echo [INFO] Use --force to recreate the virtual environment
        echo [INFO] Continuing with existing virtual environment...
        echo.
        goto setup_venv_success
    ) else (
        echo [WARNING] Virtual environment exists. Removing due to --force flag...
        rmdir /s /q "%VENV_DIR%" 2>nul
        if %VERBOSE%==1 echo [VERBOSE] Removed existing virtual environment
    )
)

REM Create virtual environment
if %VERBOSE%==1 echo [VERBOSE] Creating virtual environment at: %VENV_DIR%

if %VERBOSE%==1 (
    %PYTHON_CMD% -m venv "%VENV_DIR%"
) else (
    %PYTHON_CMD% -m venv "%VENV_DIR%" >nul 2>&1
)

if errorlevel 1 (
    echo [ERROR] Failed to create virtual environment.
    echo.
    echo This may be due to:
    echo   - Insufficient permissions
    echo   - Corrupted Python installation
    echo   - Missing venv module
    echo.
    echo Try running this script as Administrator.
    echo.
    exit /b 3
)

:setup_venv_success
echo [OK] Virtual environment ready at: %VENV_DIR%
exit /b 0

REM ----------------------------------------------------------------------------
REM Function: upgrade_pip
REM Activates venv and upgrades pip, setuptools, wheel
REM ----------------------------------------------------------------------------
:upgrade_pip
REM Check for activation script
if not exist "%VENV_DIR%\Scripts\activate.bat" (
    echo [ERROR] Virtual environment activation script not found.
    echo Expected at: %VENV_DIR%\Scripts\activate.bat
    echo.
    exit /b 3
)

REM Activate virtual environment
if %VERBOSE%==1 echo [VERBOSE] Activating virtual environment...
call "%VENV_DIR%\Scripts\activate.bat"

REM Verify activation
where python >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Failed to activate virtual environment.
    echo.
    exit /b 3
)

if %VERBOSE%==1 echo [VERBOSE] Virtual environment activated

REM Upgrade pip, setuptools, and wheel
if %VERBOSE%==1 echo [VERBOSE] Upgrading pip, setuptools, and wheel...

if %VERBOSE%==1 (
    python -m pip install --upgrade pip setuptools wheel
) else (
    echo    Upgrading packages...
    python -m pip install --upgrade pip setuptools wheel >nul 2>&1
)

if errorlevel 1 (
    echo [ERROR] Failed to upgrade pip, setuptools, and wheel.
    echo.
    echo Try running with --verbose flag for more details:
    echo   install.bat --verbose
    echo.
    exit /b 4
)

REM Get upgraded pip version
for /f "tokens=2" %%i in ('python -m pip --version 2^>^&1') do set "PIP_VERSION=%%i"
echo [OK] pip upgraded to version %PIP_VERSION%
exit /b 0

REM ----------------------------------------------------------------------------
REM Function: install_dependencies
REM Installs the package in editable mode
REM ----------------------------------------------------------------------------
:install_dependencies
REM Check if pyproject.toml exists
if not exist "%SCRIPT_DIR%\pyproject.toml" (
    echo [ERROR] pyproject.toml not found at: %SCRIPT_DIR%\pyproject.toml
    echo.
    echo Make sure you're running this script from the project root.
    echo.
    exit /b 5
)

if %VERBOSE%==1 echo [VERBOSE] Installing ai-sidecar package in editable mode...

REM Install in editable mode
if %VERBOSE%==1 (
    python -m pip install -e "%SCRIPT_DIR%"
) else (
    echo    Installing packages ^(this may take a few minutes^)...
    python -m pip install -e "%SCRIPT_DIR%" >nul 2>&1
)

if errorlevel 1 (
    echo [ERROR] Failed to install dependencies.
    echo.
    echo This may be due to:
    echo   - Network connectivity issues
    echo   - Missing build tools ^(Visual Studio Build Tools^)
    echo   - Incompatible package versions
    echo.
    echo Try running with --verbose flag for more details:
    echo   install.bat --verbose
    echo.
    exit /b 5
)

echo [OK] Dependencies installed successfully
exit /b 0

REM ----------------------------------------------------------------------------
REM Function: verify_installation
REM Verifies the installation was successful
REM ----------------------------------------------------------------------------
:verify_installation
REM Test 1: Import ai_sidecar module
if %VERBOSE%==1 echo [VERBOSE] Testing ai_sidecar module import...

python -c "import ai_sidecar" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Failed to import ai_sidecar module.
    echo.
    echo The package was installed but cannot be imported.
    echo This might indicate a configuration issue in pyproject.toml
    echo.
    exit /b 6
)
if %VERBOSE%==1 echo [VERBOSE] Module import: OK

REM Test 2: Check core dependencies
if %VERBOSE%==1 echo [VERBOSE] Testing core dependencies...

python -c "import zmq, pydantic, structlog, aiofiles" >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Some core dependencies may not be properly installed.
    echo [INFO] The installation completed, but some imports failed.
    echo.
) else (
    if %VERBOSE%==1 echo [VERBOSE] Core dependencies: OK
)

REM Test 3: Check version (if available)
if %VERBOSE%==1 (
    echo [VERBOSE] Checking package version...
    for /f "tokens=*" %%i in ('python -c "import ai_sidecar; print(getattr(ai_sidecar, '__version__', 'unknown'))" 2^>nul') do set "PKG_VERSION=%%i"
    if not "!PKG_VERSION!"=="unknown" echo [VERBOSE] Package version: !PKG_VERSION!
)

REM Test 4: Check if main module exists
if exist "%SCRIPT_DIR%\ai_sidecar\main.py" (
    if %VERBOSE%==1 echo [VERBOSE] Main module found: ai_sidecar\main.py
)

echo [OK] Installation verified successfully
exit /b 0

REM ----------------------------------------------------------------------------
REM Function: show_completion_message
REM Displays completion message with next steps
REM ----------------------------------------------------------------------------
:show_completion_message
echo.
echo ============================================================================
echo    Installation Complete!
echo ============================================================================
echo.
echo [OK] AI Sidecar has been successfully installed!
echo.
echo ============================================================================
echo Next Steps:
echo ============================================================================
echo.
echo 1. Activate the virtual environment:
echo    %VENV_DIR%\Scripts\activate.bat
echo.
echo 2. Configure your environment ^(optional^):
echo    copy .env.example .env
echo    notepad .env
echo.
echo 3. Start the AI Sidecar:
if exist "%SCRIPT_DIR%\ai_sidecar\main.py" (
    echo    cd ai_sidecar
)
echo    python main.py
echo.
echo 4. In another terminal, start OpenKore:
echo    cd "%SCRIPT_DIR%"
echo    start.exe
echo.
echo ============================================================================
echo Documentation:
echo ============================================================================
echo.
echo  * Installation Guide: %SCRIPT_DIR%\INSTALL.md
echo  * Project README:     %SCRIPT_DIR%\README.md
echo  * AI Sidecar Docs:    %SCRIPT_DIR%\ai_sidecar\README.md
echo.
echo ============================================================================
echo Tips:
echo ============================================================================
echo.
echo  * Use --verbose flag for detailed output during installation
echo  * Use --force flag to reinstall if needed
echo  * Check logs if you encounter issues
echo.
echo [*] Remember: Always activate the virtual environment before running!
echo     %VENV_DIR%\Scripts\activate.bat
echo.
exit /b 0