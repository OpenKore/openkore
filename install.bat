@echo off
REM OpenKore AI - Complete Installation Script for Windows
REM This script installs all required dependencies from scratch

setlocal enabledelayedexpansion

echo =========================================
echo   OpenKore AI - Complete Setup
echo =========================================
echo.

REM 1. Check/Install Python 3.12+
echo =========================================
echo Step 1: Python 3.12+ Installation
echo =========================================

python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python not found!
    echo.
    echo Python 3.12+ is required to run OpenKore AI.
    echo.
    echo Please download and install Python from:
    echo https://www.python.org/downloads/
    echo.
    echo IMPORTANT: During installation, check "Add Python to PATH"
    echo.
    echo After installing Python, re-run this script.
    pause
    exit /b 1
)

for /f "tokens=2" %%i in ('python --version 2^>^&1') do set PYTHON_VERSION=%%i
echo [OK] Found Python %PYTHON_VERSION%

REM Check version (basic check for 3.12+)
for /f "tokens=1,2 delims=." %%a in ("%PYTHON_VERSION%") do (
    set MAJOR=%%a
    set MINOR=%%b
)

if %MAJOR% lss 3 (
    echo [WARNING] Python 3.12+ recommended, found %PYTHON_VERSION%
) else if %MAJOR% equ 3 (
    if %MINOR% lss 12 (
        echo [WARNING] Python 3.12+ recommended, found %PYTHON_VERSION%
    )
)

REM 2. Check pip
echo.
echo =========================================
echo Step 2: pip Installation
echo =========================================

python -m pip --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARNING] pip not found, installing...
    python -m ensurepip --upgrade
    echo [OK] pip installed
) else (
    echo [OK] pip already installed
)

REM 3. Check Docker Desktop
echo.
echo =========================================
echo Step 3: Docker Desktop
echo =========================================

docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARNING] Docker not found.
    echo.
    echo Docker Desktop is required to run DragonflyDB (Redis-compatible cache).
    echo.
    echo Download Docker Desktop from:
    echo https://www.docker.com/products/docker-desktop
    echo.
    echo After installing Docker Desktop:
    echo 1. Restart your computer
    echo 2. Start Docker Desktop
    echo 3. Re-run this script
    echo.
    echo Alternative: You can install Redis for Windows manually
    echo https://github.com/microsoftarchive/redis/releases
    echo.
    set /p continue="Continue without Docker? (y/n): "
    if /i "!continue!" neq "y" (
        exit /b 0
    )
) else (
    for /f "tokens=*" %%i in ('docker --version 2^>^&1') do set DOCKER_VERSION=%%i
    echo [OK] !DOCKER_VERSION!
)

REM 4. Setup DragonflyDB
echo.
echo =========================================
echo Step 4: DragonflyDB Setup
echo =========================================

docker --version >nul 2>&1
if %errorlevel% equ 0 (
    REM Check if dragonfly container exists
    docker ps -a --format "{{.Names}}" 2>nul | findstr /x "dragonfly" >nul
    if !errorlevel! equ 0 (
        echo [OK] DragonflyDB container already exists
        
        REM Check if it's running
        docker ps --format "{{.Names}}" 2>nul | findstr /x "dragonfly" >nul
        if !errorlevel! equ 0 (
            echo [OK] DragonflyDB is running
        ) else (
            echo Starting existing DragonflyDB container...
            docker start dragonfly
            echo [OK] DragonflyDB started
        )
    ) else (
        echo Pulling DragonflyDB image...
        docker pull docker.dragonflydb.io/dragonflydb/dragonfly:latest
        
        if !errorlevel! equ 0 (
            echo Creating DragonflyDB container...
            docker run -d --name dragonfly -p 6379:6379 --restart unless-stopped docker.dragonflydb.io/dragonflydb/dragonfly:latest
            
            if !errorlevel! equ 0 (
                echo [OK] DragonflyDB running on port 6379
            ) else (
                echo [ERROR] Failed to start DragonflyDB
            )
        ) else (
            echo [ERROR] Failed to pull DragonflyDB image
        )
    )
    
    echo.
    echo DragonflyDB commands:
    echo   Stop:    docker stop dragonfly
    echo   Start:   docker start dragonfly
    echo   Logs:    docker logs dragonfly
    echo   Remove:  docker rm -f dragonfly
) else (
    echo [WARNING] DragonflyDB not installed (Docker unavailable)
    echo.
    echo Alternative: Install Redis for Windows
    echo Download: https://github.com/microsoftarchive/redis/releases
    echo Or use WSL2 with Redis installed in Linux
)

REM 5. Check Visual C++ Redistributable
echo.
echo =========================================
echo Step 5: Visual C++ Redistributable
echo =========================================

echo Checking for Visual C++ Redistributable...
reg query "HKLM\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64" >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Visual C++ Redistributable found
) else (
    echo [WARNING] Visual C++ Redistributable may be needed
    echo.
    echo If you encounter DLL errors, install from:
    echo https://aka.ms/vs/17/release/vc_redist.x64.exe
)

REM 6. Setup Python Environment
echo.
echo =========================================
echo Step 6: Python Environment Setup
echo =========================================

cd ai_sidecar

REM Create virtual environment
if not exist ".venv" (
    echo Creating Python virtual environment...
    python -m venv .venv
    echo [OK] Virtual environment created
) else (
    echo [OK] Virtual environment already exists
)

REM Activate and install dependencies
echo Activating virtual environment...
call .venv\Scripts\activate.bat

echo Upgrading pip...
python -m pip install --upgrade pip >nul 2>&1

echo Installing Python dependencies...
if exist "requirements.txt" (
    pip install -r requirements.txt
    if !errorlevel! equ 0 (
        echo [OK] Dependencies installed
    ) else (
        echo [ERROR] Failed to install dependencies
        pause
        exit /b 1
    )
) else (
    echo [ERROR] requirements.txt not found!
    pause
    exit /b 1
)

REM 7. Create .env file
echo.
echo =========================================
echo Step 7: Configuration
echo =========================================

if not exist ".env" (
    if exist ".env.example" (
        copy .env.example .env >nul
        echo [OK] Created .env from template
        echo [WARNING] Please edit ai_sidecar\.env with your settings
    ) else (
        echo [WARNING] .env.example not found, creating basic .env
        (
            echo # OpenKore AI Configuration
            echo OPENAI_API_KEY=your_openai_api_key_here
            echo REDIS_HOST=localhost
            echo REDIS_PORT=6379
            echo LOG_LEVEL=INFO
        ) > .env
        echo [OK] Created basic .env file
    )
) else (
    echo [OK] .env file already exists
)

REM 8. Installation Summary
echo.
echo =========================================
echo   Installation Complete! ^🎉
echo =========================================
echo.
echo Next steps:
echo.
echo 1. Configure your settings:
echo    notepad ai_sidecar\.env
echo.
echo 2. Start the AI system:
echo    run.bat
echo.
echo 3. Launch OpenKore:
echo    start.exe or wxstart.exe
echo.
echo =========================================
echo.

REM Check for Docker installation reminder
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [REMINDER] Install Docker Desktop for DragonflyDB support
    echo.
)

pause