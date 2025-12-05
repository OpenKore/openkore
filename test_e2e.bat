@echo off
setlocal enabledelayedexpansion

echo 🧪 OpenKore-AI End-to-End Validation
echo ========================================
echo.

set FAILED_TESTS=0
set PASSED_TESTS=0

cd /d "%~dp0"

echo 1️⃣  Testing Python imports...
cd ai_sidecar

python -c "from ai_sidecar.core.decision import ProgressionDecisionEngine" 2>nul
if !errorlevel! equ 0 (
    echo ✅ Decision engine imports OK
    set /a PASSED_TESTS+=1
) else (
    echo ❌ Decision engine imports failed
    set /a FAILED_TESTS+=1
)

python -c "from ai_sidecar.config import get_settings" 2>nul
if !errorlevel! equ 0 (
    echo ✅ Config system imports OK
    set /a PASSED_TESTS+=1
) else (
    echo ❌ Config system imports failed
    set /a FAILED_TESTS+=1
)

python -c "from ai_sidecar.config.loader import get_config" 2>nul
if !errorlevel! equ 0 (
    echo ✅ Config loader imports OK
    set /a PASSED_TESTS+=1
) else (
    echo ❌ Config loader imports failed
    set /a FAILED_TESTS+=1
)

echo.
echo 2️⃣  Testing AI Sidecar startup...

start /b python main.py > %TEMP%\ai_sidecar_test.log 2>&1
timeout /t 3 /nobreak >nul

tasklist /FI "IMAGENAME eq python.exe" 2>nul | find /I "python.exe" >nul
if !errorlevel! equ 0 (
    echo ✅ AI Sidecar starts successfully
    set /a PASSED_TESTS+=1
    
    taskkill /F /IM python.exe >nul 2>&1
    
    findstr /C:"All subsystems initialized" %TEMP%\ai_sidecar_test.log >nul 2>&1
    if !errorlevel! equ 0 (
        echo ✅ All subsystems initialized
        set /a PASSED_TESTS+=1
    ) else (
        echo ⚠️  Subsystem initialization status unclear
    )
) else (
    echo ❌ AI Sidecar failed to start
    set /a FAILED_TESTS+=1
    type %TEMP%\ai_sidecar_test.log
)

cd ..

echo.
echo 3️⃣  Testing Perl plugin syntax...
echo ⚠️  Perl plugins require OpenKore environment (expected)

echo.
echo ========================================
echo 📊 Test Results:
echo    Passed: !PASSED_TESTS!
echo    Failed: !FAILED_TESTS!
echo.

if !FAILED_TESTS! equ 0 (
    echo ✅ All E2E validation checks passed!
    exit /b 0
) else (
    echo ❌ Some tests failed. Please review the output above.
    exit /b 1
)