@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ==========================================
echo RK3588 Test Deploy
echo ==========================================
echo.

cd /d %~dp0

echo Step 1: Check compiled binary...
if not exist "..\..\build_rk3588_new\bin_arm64\belt_control_system" (
    echo Error: belt_control_system not found
    echo Please compile first
    pause
    exit /b 1
)
echo OK: Binary found

echo.
echo Step 2: Check Docker...
docker --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Error: Docker not installed
    pause
    exit /b 1
)
echo OK: Docker installed

echo.
echo Step 3: Save binary for deployment...
mkdir runtime-test 2>nul
copy "..\..\build_rk3588_new\bin_arm64\belt_control_system" "runtime-test\" >nul
echo OK: Binary copied

echo.
echo Step 4: Test SSH connection...
ssh pi@192.168.10.170 "echo OK" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Error: Cannot connect to 192.168.10.170
    pause
    exit /b 1
)
echo OK: SSH connection working

echo.
echo Step 5: Check Docker on remote...
ssh pi@192.168.10.170 "docker --version" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Error: Docker not installed on remote
    pause
    exit /b 1
)
echo OK: Docker running on remote

echo.
echo ==========================================
echo All checks passed!
echo ==========================================
echo.
echo Ready to deploy. Next steps:
echo   1. Build Docker image locally
echo   2. Save image to tar
echo   3. Transfer to remote
echo   4. Load and run on remote
echo.

pause
