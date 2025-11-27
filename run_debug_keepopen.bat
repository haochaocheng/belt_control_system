@echo off
echo ========================================
echo Belt Control System - Debug Mode
echo Console will stay open after crash
echo ========================================
echo.

cd /d "%~dp0"
build\bin_windows\belt_control_system.exe

echo.
echo ========================================
echo Program exited or crashed
echo Press any key to close this window...
echo ========================================
pause > nul
