@echo off
setlocal enabledelayedexpansion

REM ============================================================================
REM OpenKore AI - Quick Start Script for Windows
REM
REM This script provides a one-click startup experience for the OpenKore AI bot
REM system. It automatically starts both the AI Sidecar and OpenKore bot.
REM
REM Usage:
REM   quick-start.bat [OPTIONS]
REM
REM Options:
REM   --help, /?, /h, -h   Show this help message
REM
REM Requirements:
REM   - Virtual environment must be installed (run install.bat first)
REM   - AI Sidecar configured (optional .env file)
REM
REM To stop both services:
REM   - Press Ctrl+C in each terminal window
REM   - Or close the terminal windows
REM ============================================================================

REM Configuration
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "VENV_DIR=%SCRIPT_DIR%\ai_sidecar\.venv"
set "AI_SIDECAR_DIR=%SCRIPT_DIR%\ai_sidecar"
set "ENV_FILE=%AI_SIDECAR_DIR%\.env"
set "ENV_EXAMPLE=%AI_SIDECAR_DIR%\.env.example"
set "OPENKORE_EXE=%SCRIPT_DIR%\start.exe"

REM Colors (using standard Windows console codes)
set "COLOR_RESET=[0m"
set "COLOR_GREEN=[92m"
set "COLOR_YELLOW=[93m"
set "COLOR_RED=[91m"
set "COLOR_CYAN=[96m"
set "COLOR_BLUE=[94m"

REM Parse command-line arguments
:parse_args
if "%~1"=="" goto end_parse_args
if /i "%~1"=="/?" goto show_help
if /i "%~1"=="--help" goto show_help
if /i "%~1"=="/h" goto show_help
if /i "%~1"=="-h" goto show_help
shift
goto parse_args
:end_parse_args

REM ============================================================================
REM Main Startup Process
REM ============================================================================

cls
echo.
echo %COLOR_CYAN%============================================================================%COLOR_RESET%
echo %COLOR_CYAN%   OpenKore AI - Quick Start%COLOR_RESET%
echo %COLOR_CYAN%============================================================================%COLOR_RESET%
echo.

REM Step 1: Check Prerequisites
echo %COLOR_BLUE%[1/5]%COLOR_RESET% Checking prerequisites...
call :check_prerequisites
if errorlevel 1 (
    echo.
    echo %COLOR_RED%[ERROR] Prerequisites check failed!%COLOR_RESET%
    echo.
    pause
    exit /b 1
)

REM Step 2: Environment Setup
echo %COLOR_BLUE%[2/5]%COLOR_RESET% Checking environment configuration...
call :check_environment
if errorlevel 1 (
    echo.
    echo %COLOR_YELLOW%[WARNING] Environment setup cancelled by user.%COLOR_RESET%
    echo.
    pause
    exit /b 1
)

REM Step 3: Start AI Sidecar
echo %COLOR_BLUE%[3/5]%COLOR_RESET% Starting AI Sidecar...
call :start_ai_sidecar
if errorlevel 1 (
    echo.
    echo %COLOR_RED%[ERROR] Failed to start AI Sidecar!%COLOR_RESET%
    echo.
    pause
    exit /b 1
)

REM Step 4: Wait for AI Sidecar to initialize
echo %COLOR_BLUE%[4/5]%COLOR_RESET% Waiting for AI Sidecar to initialize...
call :wait_for_sidecar

REM Step 5: Start OpenKore
echo %COLOR_BLUE%[5/5]%COLOR_RESET% Starting OpenKore...
call :start_openkore
if errorlevel 1 (
    echo.
    echo %COLOR_RED%[ERROR] Failed to start OpenKore!%COLOR_RESET%
    echo.
    pause
    exit /b 1
)

REM Success!
call :show_success_message
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
echo OpenKore AI - Quick Start Script
echo.
echo USAGE:
echo   quick-start.bat [OPTIONS]
echo.
echo OPTIONS:
echo   --help, /?, /h, -h   Show this help message
echo.
echo DESCRIPTION:
echo   This script provides a one-click startup for the OpenKore AI system.
echo   It automatically:
echo.
echo   1. Verifies prerequisites ^(virtual environment, files^)
echo   2. Checks/configures environment ^(.env file^)
echo   3. Starts AI Sidecar in a new terminal
echo   4. Waits for AI Sidecar to initialize
echo   5. Starts OpenKore bot
echo.
echo REQUIREMENTS:
echo   - Virtual environment must be installed
echo     Run: install.bat
echo.
echo   - AI Sidecar configured ^(optional .env file^)
echo     File: ai_sidecar\.env
echo.
echo STOPPING SERVICES:
echo   To stop both services:
echo   - Press Ctrl+C in each terminal window
echo   - Or simply close the terminal windows
echo.
echo For installation help, run: install.bat --help
echo.
exit /b 0

REM ----------------------------------------------------------------------------
REM Function: check_prerequisites
REM Verifies that all required files and directories exist
REM ----------------------------------------------------------------------------
:check_prerequisites
REM Check if we're in the correct directory
if not exist "%SCRIPT_DIR%\pyproject.toml" (
    echo %COLOR_RED%[ERROR] pyproject.toml not found!%COLOR_RESET%
    echo.
    echo Please run this script from the openkore-AI directory.
    echo Current directory: %CD%
    echo.
    exit /b 1
)

REM Check if virtual environment exists
if not exist "%VENV_DIR%\Scripts\python.exe" (
    echo %COLOR_RED%[ERROR] Virtual environment not found!%COLOR_RESET%
    echo.
    echo The virtual environment does not exist at:
    echo   %VENV_DIR%
    echo.
    echo Please run the installation script first:
    echo   %COLOR_GREEN%install.bat%COLOR_RESET%
    echo.
    exit /b 1
)

REM Check if AI Sidecar main.py exists
if not exist "%AI_SIDECAR_DIR%\main.py" (
    echo %COLOR_RED%[ERROR] AI Sidecar main.py not found!%COLOR_RESET%
    echo.
    echo Expected at: %AI_SIDECAR_DIR%\main.py
    echo.
    exit /b 1
)

REM Check if OpenKore start.exe exists
if not exist "%OPENKORE_EXE%" (
    echo %COLOR_RED%[ERROR] OpenKore start.exe not found!%COLOR_RESET%
    echo.
    echo Expected at: %OPENKORE_EXE%
    echo.
    exit /b 1
)

echo %COLOR_GREEN%[OK]%COLOR_RESET% All prerequisites verified
exit /b 0

REM ----------------------------------------------------------------------------
REM Function: check_environment
REM Checks for .env file and offers to create it from example
REM ----------------------------------------------------------------------------
:check_environment
REM Check if .env file exists
if exist "%ENV_FILE%" (
    echo %COLOR_GREEN%[OK]%COLOR_RESET% Environment file found: .env
    exit /b 0
)

REM .env doesn't exist, check if .env.example exists
if not exist "%ENV_EXAMPLE%" (
    echo %COLOR_YELLOW%[WARNING] No .env or .env.example file found%COLOR_RESET%
    echo.
    echo The AI Sidecar will use default settings.
    echo You can create a .env file later for custom configuration.
    echo.
    echo Continue with default settings? ^(Y/N^)
    set /p "continue_default=Choice: "
    if /i "!continue_default!"=="Y" (
        echo.
        echo %COLOR_CYAN%[INFO]%COLOR_RESET% Continuing with default settings...
        exit /b 0
    ) else (
        exit /b 1
    )
)

REM .env.example exists, ask user if they want to copy it
echo %COLOR_YELLOW%[INFO]%COLOR_RESET% No .env file found
echo.
echo A .env.example file is available with default configuration.
echo.
echo Would you like to copy it to .env now? ^(Y/N^)
set /p "copy_env=Choice: "

if /i "!copy_env!"=="Y" (
    echo.
    echo %COLOR_CYAN%[INFO]%COLOR_RESET% Copying .env.example to .env...
    copy "%ENV_EXAMPLE%" "%ENV_FILE%" >nul 2>&1
    if errorlevel 1 (
        echo %COLOR_RED%[ERROR] Failed to copy .env.example to .env%COLOR_RESET%
        echo.
        exit /b 1
    )
    echo %COLOR_GREEN%[OK]%COLOR_RESET% Environment file created: .env
    echo.
    echo %COLOR_CYAN%[INFO]%COLOR_RESET% You may want to edit the .env file to configure:
    echo   - API keys ^(OpenAI, Anthropic, etc.^)
    echo   - Redis connection
    echo   - Log settings
    echo.
    echo Would you like to open .env for editing now? ^(Y/N^)
    set /p "edit_env=Choice: "
    if /i "!edit_env!"=="Y" (
        echo.
        echo %COLOR_CYAN%[INFO]%COLOR_RESET% Opening .env in notepad...
        echo Close notepad when finished editing to continue...
        start /wait notepad "%ENV_FILE%"
    )
    echo.
    exit /b 0
) else (
    echo.
    echo %COLOR_YELLOW%[WARNING]%COLOR_RESET% Continuing without .env file
    echo The AI Sidecar will use default settings.
    echo.
    echo Continue? ^(Y/N^)
    set /p "continue_no_env=Choice: "
    if /i "!continue_no_env!"=="Y" (
        exit /b 0
    ) else (
        exit /b 1
    )
)

exit /b 0

REM ----------------------------------------------------------------------------
REM Function: start_ai_sidecar
REM Starts the AI Sidecar in a new terminal window
REM ----------------------------------------------------------------------------
:start_ai_sidecar
echo.
echo %COLOR_CYAN%[INFO]%COLOR_RESET% Launching AI Sidecar in new terminal...

REM Create a temporary batch file to run in the new window
set "TEMP_SCRIPT=%TEMP%\openkore_ai_sidecar_%RANDOM%.bat"

REM Write the startup commands to temporary script
(
    echo @echo off
    echo title OpenKore AI - AI Sidecar
    echo echo.
    echo echo ============================================================================
    echo echo    OpenKore AI - AI Sidecar
    echo echo ============================================================================
    echo echo.
    echo echo %COLOR_CYAN%[INFO]%COLOR_RESET% Activating virtual environment...
    echo call "%VENV_DIR%\Scripts\activate.bat"
    echo if errorlevel 1 ^(
    echo     echo %COLOR_RED%[ERROR] Failed to activate virtual environment!%COLOR_RESET%
    echo     pause
    echo     exit /b 1
    echo ^)
    echo echo %COLOR_GREEN%[OK]%COLOR_RESET% Virtual environment activated
    echo echo.
    echo echo %COLOR_CYAN%[INFO]%COLOR_RESET% Starting AI Sidecar...
    echo echo.
    echo cd /d "%AI_SIDECAR_DIR%"
    echo python main.py
    echo echo.
    echo echo %COLOR_RED%AI Sidecar has stopped.%COLOR_RESET%
    echo pause
    echo del "%%~f0"
) > "%TEMP_SCRIPT%"

REM Start the new terminal window
start "OpenKore AI - AI Sidecar" cmd /k "%TEMP_SCRIPT%"

if errorlevel 1 (
    echo %COLOR_RED%[ERROR] Failed to start new terminal window%COLOR_RESET%
    del "%TEMP_SCRIPT%" 2>nul
    exit /b 1
)

REM The temp script will delete itself after execution, so no cleanup needed here
REM timeout /t 1 /nobreak >nul 2>&1
REM del "%TEMP_SCRIPT%" 2>nul

echo %COLOR_GREEN%[OK]%COLOR_RESET% AI Sidecar started in new terminal
exit /b 0

REM ----------------------------------------------------------------------------
REM Function: wait_for_sidecar
REM Waits for AI Sidecar to initialize
REM ----------------------------------------------------------------------------
:wait_for_sidecar
echo.
echo %COLOR_CYAN%[INFO]%COLOR_RESET% Waiting for AI Sidecar to initialize...
echo.

REM Countdown from 3 seconds
for /l %%i in (3,-1,1) do (
    echo    Starting OpenKore in %%i seconds...
    timeout /t 1 /nobreak >nul 2>&1
)

echo.
echo %COLOR_GREEN%[OK]%COLOR_RESET% AI Sidecar should be ready
exit /b 0

REM ----------------------------------------------------------------------------
REM Function: start_openkore
REM Starts OpenKore
REM ----------------------------------------------------------------------------
:start_openkore
echo.
echo %COLOR_CYAN%[INFO]%COLOR_RESET% Launching OpenKore...

REM Start OpenKore
start "OpenKore AI - Bot" "%OPENKORE_EXE%"

if errorlevel 1 (
    echo %COLOR_RED%[ERROR] Failed to start OpenKore%COLOR_RESET%
    echo.
    echo Make sure start.exe is present at:
    echo   %OPENKORE_EXE%
    echo.
    exit /b 1
)

echo %COLOR_GREEN%[OK]%COLOR_RESET% OpenKore started
exit /b 0

REM ----------------------------------------------------------------------------
REM Function: show_success_message
REM Displays success message with instructions
REM ----------------------------------------------------------------------------
:show_success_message
echo.
echo %COLOR_GREEN%============================================================================%COLOR_RESET%
echo %COLOR_GREEN%   All Services Started Successfully!%COLOR_RESET%
echo %COLOR_GREEN%============================================================================%COLOR_RESET%
echo.
echo %COLOR_CYAN%Running Services:%COLOR_RESET%
echo   %COLOR_GREEN%✓%COLOR_RESET% AI Sidecar    - Running in separate terminal
echo   %COLOR_GREEN%✓%COLOR_RESET% OpenKore Bot  - Running in separate window
echo.
echo %COLOR_CYAN%Next Steps:%COLOR_RESET%
echo   1. Monitor the AI Sidecar terminal for AI activity
echo   2. Configure OpenKore bot settings as needed
echo   3. The bot will use AI for decision-making
echo.
echo %COLOR_CYAN%To Stop Services:%COLOR_RESET%
echo   • Press %COLOR_YELLOW%Ctrl+C%COLOR_RESET% in the AI Sidecar terminal
echo   • Close the OpenKore window or type 'quit'
echo   • Or close both terminal windows
echo.
echo %COLOR_CYAN%Troubleshooting:%COLOR_RESET%
echo   • Check AI Sidecar terminal for connection status
echo   • Verify .env configuration if using API keys
echo   • See logs in ai_sidecar/logs/ for detailed info
echo.
echo %COLOR_CYAN%For help:%COLOR_RESET% quick-start.bat --help
echo.
exit /b 0