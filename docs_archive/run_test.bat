@echo off
chcp 65001 >nul
set PATH=C:\Qt\6.5.3\mingw_64\bin;%PATH%
set QT_PLUGIN_PATH=C:\Qt\6.5.3\mingw_64\plugins
set QT_QPA_PLATFORM_PLUGIN_PATH=C:\Qt\6.5.3\mingw_64\plugins\platforms
set QML_IMPORT_PATH=%CD%\src\qml;C:\Qt\6.5.3\mingw_64\qml
set QML2_IMPORT_PATH=%CD%\src\qml;C:\Qt\6.5.3\mingw_64\qml
set QT_DEBUG_PLUGINS=1

echo Running application with debug output...
echo.
build\bin_windows\belt_control_system.exe 2>&1
echo.
echo Exit code: %ERRORLEVEL%
pause
