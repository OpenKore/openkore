@echo off
REM OpenKore AI - Windows Run Script with DragonflyDB Check

setlocal enabledelayedexpansion

echo =========================================
echo   OpenKore AI - Startup
echo =========================================
echo.

REM Check if DragonflyDB/Redis is running
echo Checking cache server (DragonflyDB/Redis)...

docker --version >nul 2>&1
if %errorlevel% equ 0 (
    REM Docker is available, check for dragonfly container
    docker ps -a --format "{{.Names}}" 2>nul | findstr /x "dragonfly" >nul
    if !errorlevel! equ 0 (
        REM Container exists, check if running
        docker ps --format "{{.Names}}" 2>nul | findstr /x "dragonfly" >nul
        if !errorlevel! equ 0 (
            echo [OK] DragonflyDB is running
        ) else (
            echo [WARNING] DragonflyDB container exists but not running
            echo Starting DragonflyDB...
            docker start dragonfly >nul 2>&1
            if !errorlevel! equ 0 (
                echo [OK] DragonflyDB started successfully
                timeout /t 2 /nobreak >nul
            ) else (
                echo [ERROR] Failed to start DragonflyDB
                echo Try running: docker start dragonfly
                pause
                exit /b 1
            )
        )
    ) else (
        echo [WARNING] DragonflyDB container not found
        echo.
        set /p create_dragonfly="Would you like to create and start DragonflyDB now? (y/n): "
        
        if /i "!create_dragonfly!"=="y" (
            echo Pulling DragonflyDB image...
            docker pull docker.dragonflydb.io/dragonflydb/dragonfly:latest
            
            echo Creating DragonflyDB container...
            docker run -d --name dragonfly -p 6379:6379 --restart unless-stopped docker.dragonflydb.io/dragonflydb/dragonfly:latest
            
            if !errorlevel! equ 0 (
                echo [OK] DragonflyDB created and started
                timeout /t 2 /nobreak >nul
            ) else (
                echo [ERROR] Failed to create DragonflyDB
                pause
                exit /b 1
            )
        ) else (
            echo [ERROR] DragonflyDB is required. Please run install.bat first
            pause
            exit /b 1
        )
    )
) else (
    REM Docker not available, check for Redis
    redis-cli ping >nul 2>&1
    if !errorlevel! equ 0 (
        echo [OK] Redis is running
    ) else (
        echo [WARNING] Neither Docker nor Redis found or not running
        echo.
        echo Please ensure one of the following:
        echo 1. Install Docker Desktop and run install.bat
        echo 2. Install Redis for Windows manually
        echo.
        pause
        exit /b 1
    )
)

echo.
echo Starting OpenKore AI Sidecar...
echo =========================================
echo.

REM Navigate to ai_sidecar
cd ai_sidecar

if not exist ".venv" (
    echo [ERROR] Virtual environment not found!
    echo Please run install.bat first
    pause
    exit /b 1
)

REM Activate virtual environment
call .venv\Scripts\activate.bat

REM Check if .env exists
if not exist ".env" (
    echo [ERROR] .env file not found!
    echo Please create ai_sidecar\.env with your configuration
    echo You can copy from .env.example
    pause
    exit /b 1
)

REM Set PYTHONPATH and run
set PYTHONPATH=%CD%\..
python main.py %*