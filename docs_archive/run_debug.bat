@echo off
echo Running application with debug output...
cd /d "%~dp0"
set QT_LOGGING_RULES=*.debug=true;qt.qml.connections=false
set QT_DEBUG_PLUGINS=1
build\bin_windows\belt_control_system.exe 2>&1
echo.
echo Application exited with code: %ERRORLEVEL%
pause
