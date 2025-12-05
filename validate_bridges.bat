@echo off
REM
REM OpenKore-AI Bridge System Validation Script (Windows)
REM Tests all bridge components and dependencies
REM
REM Usage: validate_bridges.bat
REM

setlocal enabledelayedexpansion

REM Counters
set /a CHECKS_PASSED=0
set /a CHECKS_FAILED=0
set /a CHECKS_WARNING=0

echo.
echo   ___                   _  __              _    ___ 
echo  / _ \ _ __   ___ _ __ ^| ^|/ /___  _ __ ___      / \ ^|
echo ^| ^| ^| ^| '_ \ / _ \ '_ \^| ' // _ \^| '__/ _ \    / _ \^|
echo ^| ^|_^| ^| ^|_) ^|  __/ ^| ^| ^| . \ (_) ^| ^| ^|  __/   / ___ \
echo  \___/^| .__/ \___^|_^| ^|_^|_^|\_\___/^|_^|  \___^|  /_/   \_\
echo       ^|_^|                                              
echo          Bridge System Validation (Windows)
echo.
echo ================================================
echo   System Environment Validation
echo ================================================
echo.

REM Check Windows version
echo [Operating System]
ver | findstr /i "Windows" >nul
if !errorlevel! equ 0 (
    echo   [32m√[0m Windows detected
    set /a CHECKS_PASSED+=1
    ver
) else (
    echo   [31mX[0m Cannot determine Windows version
    set /a CHECKS_WARNING+=1
)
echo.

echo ================================================
echo   Core Dependencies Check
echo ================================================
echo.

REM Check Perl
echo [Perl Installation]
where perl >nul 2>&1
if !errorlevel! equ 0 (
    echo   [32m√[0m Perl found
    set /a CHECKS_PASSED+=1
    perl -v | findstr "version"
) else (
    echo   [31mX[0m Perl not found
    echo      ^-^> Install from: https://strawberryperl.com/
    set /a CHECKS_FAILED+=1
)
echo.

REM Check Python
echo [Python Installation]
where python >nul 2>&1
if !errorlevel! equ 0 (
    echo   [32m√[0m Python found
    set /a CHECKS_PASSED+=1
    python --version
    
    REM Check Python version
    for /f "tokens=2" %%i in ('python --version 2^>^&1') do set PYTHON_VER=%%i
    echo      Python version: !PYTHON_VER!
) else (
    echo   [31mX[0m Python not found
    echo      ^-^> Install from: https://www.python.org/downloads/
    set /a CHECKS_FAILED+=1
)
echo.

echo ================================================
echo   Perl Module Dependencies
echo ================================================
echo.

REM Check ZMQ::FFI
echo [ZeroMQ Perl Binding]
perl -MZMQ::FFI -e "print 'installed'" >nul 2>&1
if !errorlevel! equ 0 (
    echo   [32m√[0m ZMQ::FFI module installed
    set /a CHECKS_PASSED+=1
) else (
    echo   [31mX[0m ZMQ::FFI not found
    echo      ^-^> Install: cpanm ZMQ::FFI
    echo      ^-^> Or: ppm install ZMQ-FFI (ActivePerl)
    set /a CHECKS_FAILED+=1
)
echo.

REM Check JSON::XS
echo [JSON Parser]
perl -MJSON::XS -e "print 'installed'" >nul 2>&1
if !errorlevel! equ 0 (
    echo   [32m√[0m JSON::XS module installed
    set /a CHECKS_PASSED+=1
) else (
    echo   [33m![0m JSON::XS not found
    echo      ^-^> Install: cpanm JSON::XS (improves performance)
    echo      ^-^> Fallback to JSON::PP available
    set /a CHECKS_WARNING+=1
)
echo.

REM Check Time::HiRes
echo [High-Resolution Timer]
perl -MTime::HiRes -e "print 'installed'" >nul 2>&1
if !errorlevel! equ 0 (
    echo   [32m√[0m Time::HiRes module installed
    set /a CHECKS_PASSED+=1
) else (
    echo   [33m![0m Time::HiRes not found
    echo      ^-^> Usually included with Perl
    set /a CHECKS_WARNING+=1
)
echo.

echo ================================================
echo   OpenKore Plugin Files
echo ================================================
echo.

REM Check AI_Bridge plugin
echo [AI Bridge Plugin]
if exist "plugins\AI_Bridge.pl" (
    echo   [32m√[0m AI_Bridge.pl found
    set /a CHECKS_PASSED+=1
    
    REM Basic syntax check
    perl -c plugins\AI_Bridge.pl >nul 2>&1
    if !errorlevel! equ 0 (
        echo   [32m√[0m AI_Bridge.pl syntax valid
        set /a CHECKS_PASSED+=1
    ) else (
        echo   [31mX[0m AI_Bridge.pl has syntax errors
        echo      ^-^> Run: perl -c plugins\AI_Bridge.pl
        set /a CHECKS_FAILED+=1
    )
) else (
    echo   [31mX[0m AI_Bridge.pl not found
    echo      ^-^> Should be at: plugins\AI_Bridge.pl
    set /a CHECKS_FAILED+=1
)
echo.

REM Check chat bridge plugin
echo [Chat Bridge Plugin]
if exist "plugins\godtier_chat_bridge.pl" (
    echo   [32m√[0m godtier_chat_bridge.pl found
    set /a CHECKS_PASSED+=1
    
    perl -c plugins\godtier_chat_bridge.pl >nul 2>&1
    if !errorlevel! equ 0 (
        echo   [32m√[0m godtier_chat_bridge.pl syntax valid
        set /a CHECKS_PASSED+=1
    ) else (
        echo   [31mX[0m godtier_chat_bridge.pl has syntax errors
        set /a CHECKS_FAILED+=1
    )
) else (
    echo   [33m![0m godtier_chat_bridge.pl not found
    echo      ^-^> Chat features will be limited
    set /a CHECKS_WARNING+=1
)
echo.

echo ================================================
echo   Python AI Sidecar Dependencies
echo ================================================
echo.

REM Check ai_sidecar directory
echo [AI Sidecar Directory]
if exist "ai_sidecar\" (
    echo   [32m√[0m ai_sidecar directory found
    set /a CHECKS_PASSED+=1
) else (
    echo   [31mX[0m ai_sidecar directory not found
    echo      ^-^> Ensure you're in openkore-AI root
    set /a CHECKS_FAILED+=1
    goto :summary
)
echo.

REM Check virtual environment
echo [Python Virtual Environment]
if exist "ai_sidecar\.venv\" (
    echo   [32m√[0m Virtual environment found (.venv)
    set /a CHECKS_PASSED+=1
) else if exist "ai_sidecar\venv\" (
    echo   [32m√[0m Virtual environment found (venv)
    set /a CHECKS_PASSED+=1
) else (
    echo   [33m![0m No virtual environment found
    echo      ^-^> Recommended: cd ai_sidecar ^&^& python -m venv .venv
    set /a CHECKS_WARNING+=1
)
echo.

REM Check requirements.txt
echo [Python Requirements File]
if exist "ai_sidecar\requirements.txt" (
    echo   [32m√[0m requirements.txt found
    set /a CHECKS_PASSED+=1
) else (
    echo   [31mX[0m requirements.txt not found
    set /a CHECKS_FAILED+=1
)
echo.

REM Check Python dependencies (if venv exists)
if exist "ai_sidecar\.venv\Scripts\python.exe" (
    echo [Python Dependencies Check]
    
    REM Check pyzmq
    ai_sidecar\.venv\Scripts\python.exe -c "import zmq" >nul 2>&1
    if !errorlevel! equ 0 (
        echo   [32m√[0m pyzmq installed
        set /a CHECKS_PASSED+=1
    ) else (
        echo   [31mX[0m pyzmq not installed
        echo      ^-^> Install: pip install pyzmq^>=25.1.0
        set /a CHECKS_FAILED+=1
    )
    
    REM Check pydantic
    ai_sidecar\.venv\Scripts\python.exe -c "import pydantic" >nul 2>&1
    if !errorlevel! equ 0 (
        echo   [32m√[0m pydantic installed
        set /a CHECKS_PASSED+=1
    ) else (
        echo   [31mX[0m pydantic not installed
        echo      ^-^> Install: pip install pydantic^>=2.5.0
        set /a CHECKS_FAILED+=1
    )
    
    REM Check structlog
    ai_sidecar\.venv\Scripts\python.exe -c "import structlog" >nul 2>&1
    if !errorlevel! equ 0 (
        echo   [32m√[0m structlog installed
        set /a CHECKS_PASSED+=1
    ) else (
        echo   [33m![0m structlog not installed
        echo      ^-^> Install: pip install structlog
        set /a CHECKS_WARNING+=1
    )
) else (
    echo   [33m![0m Cannot check Python dependencies
    echo      ^-^> No active virtual environment
    set /a CHECKS_WARNING+=1
)
echo.

echo ================================================
echo   Configuration Files
echo ================================================
echo.

echo [AI Sidecar Configuration]
if exist "ai_sidecar\config.yaml" (
    echo   [32m√[0m config.yaml found
    set /a CHECKS_PASSED+=1
)
if exist "ai_sidecar\.env" (
    echo   [32m√[0m .env found
    set /a CHECKS_PASSED+=1
)
if not exist "ai_sidecar\config.yaml" if not exist "ai_sidecar\.env" (
    echo   [33m![0m No configuration files found
    echo      ^-^> Copy .env.example to .env and configure
    set /a CHECKS_WARNING+=1
)
echo.

echo [OpenKore Configuration]
if exist "control\config.txt" (
    echo   [32m√[0m control\config.txt found
    set /a CHECKS_PASSED+=1
) else (
    echo   [33m![0m control\config.txt not found
    echo      ^-^> OpenKore may not be configured yet
    set /a CHECKS_WARNING+=1
)
echo.

echo ================================================
echo   Network Connectivity
echo ================================================
echo.

echo [ZeroMQ Port Availability]
netstat -ano | findstr ":5555" >nul 2>&1
if !errorlevel! equ 0 (
    echo   [33m![0m Port 5555 already in use
    echo      ^-^> AI Sidecar may be running
    set /a CHECKS_WARNING+=1
) else (
    echo   [32m√[0m Port 5555 available
    set /a CHECKS_PASSED+=1
)
echo.

echo [Localhost Connectivity]
ping -n 1 127.0.0.1 >nul 2>&1
if !errorlevel! equ 0 (
    echo   [32m√[0m Localhost reachable
    set /a CHECKS_PASSED+=1
) else (
    echo   [31mX[0m Cannot ping localhost
    set /a CHECKS_FAILED+=1
)
echo.

echo ================================================
echo   Optional Dependencies
echo ================================================
echo.

REM Check Docker
echo [Docker (Optional)]
where docker >nul 2>&1
if !errorlevel! equ 0 (
    echo   [32m√[0m Docker installed
    set /a CHECKS_PASSED+=1
    docker --version
    
    REM Check DragonflyDB container
    docker ps 2>nul | findstr "dragonfly" >nul
    if !errorlevel! equ 0 (
        echo   [32m√[0m DragonflyDB container running
        set /a CHECKS_PASSED+=1
    ) else (
        echo   [33m![0m No DragonflyDB container running
        echo      ^-^> Optional for session memory
        set /a CHECKS_WARNING+=1
    )
) else (
    echo   [33m![0m Docker not installed
    echo      ^-^> Optional for easy DragonflyDB setup
    set /a CHECKS_WARNING+=1
)
echo.

REM Check Redis CLI
echo [Redis/DragonflyDB (Optional)]
where redis-cli >nul 2>&1
if !errorlevel! equ 0 (
    redis-cli -h localhost -p 6379 ping >nul 2>&1
    if !errorlevel! equ 0 (
        echo   [32m√[0m Redis/DragonflyDB running
        set /a CHECKS_PASSED+=1
    ) else (
        echo   [33m![0m Redis/DragonflyDB not running
        echo      ^-^> Optional for session memory
        set /a CHECKS_WARNING+=1
    )
) else (
    echo   [33m![0m redis-cli not found
    echo      ^-^> Optional for session memory
    set /a CHECKS_WARNING+=1
)
echo.

REM Check GPU (NVIDIA)
echo [GPU Support (Optional)]
where nvidia-smi >nul 2>&1
if !errorlevel! equ 0 (
    echo   [32m√[0m NVIDIA GPU detected
    set /a CHECKS_PASSED+=1
    nvidia-smi --query-gpu=name --format=csv,noheader
) else (
    echo   [33m![0m No NVIDIA GPU detected
    echo      ^-^> Optional for GPU acceleration mode
    set /a CHECKS_WARNING+=1
)
echo.

:summary
echo ================================================
echo   Final Summary
echo ================================================
echo.
echo   [32m√[0m Checks Passed:  !CHECKS_PASSED!
if !CHECKS_WARNING! gtr 0 (
    echo   [33m![0m Warnings:       !CHECKS_WARNING!
)
if !CHECKS_FAILED! gtr 0 (
    echo   [31mX[0m Checks Failed:  !CHECKS_FAILED!
)
echo.

if !CHECKS_FAILED! equ 0 (
    echo ================================================
    echo   [32m√ VALIDATION PASSED![0m
    echo ================================================
    echo.
    echo [36mNext Steps:[0m
    echo   1. Start AI Sidecar: [33mcd ai_sidecar ^&^& python main.py[0m
    echo   2. Start OpenKore:   [33mstart.exe[0m
    echo   3. Monitor logs for bridge connection
    echo.
    exit /b 0
) else (
    echo ================================================
    echo   [31mX VALIDATION FAILED[0m
    echo ================================================
    echo.
    echo [33mPlease fix the errors above before proceeding[0m
    echo.
    echo [36mResources:[0m
    echo   * Documentation: docs\GODTIER-RO-AI-DOCUMENTATION.md
    echo   * Testing Guide: docs\BRIDGE_TESTING_GUIDE.md
    echo   * Troubleshooting: BRIDGE_TROUBLESHOOTING.md
    echo.
    exit /b 1
)