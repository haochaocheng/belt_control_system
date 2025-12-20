@echo off
chcp 65001 >nul
REM ========================================
REM Belt Control System - Auto-deploy runtime dependencies
REM Deploys all required DLLs and QML modules after rebuild
REM ========================================

setlocal enabledelayedexpansion

echo ========================================
echo Deploying runtime dependencies to build\bin_windows
echo ========================================
echo.

set "BUILD_DIR=%~dp0build\bin_windows"
set "QT_BIN=C:\Qt\6.5.3\mingw_64\bin"
set "QT_QML=C:\Qt\6.5.3\mingw_64\qml"
set "MSYS2_BIN=C:\msys64\mingw64\bin"
set "FFMPEG_BIN=C:\ffmpeg\bin"
set "SDL2_LIB=C:\video_deps\SDL2-2.28.5\lib\x64"
set "QML_SOURCE=%~dp0src\qml"

REM Check if target directory exists
if not exist "%BUILD_DIR%" (
    echo ERROR: build\bin_windows directory does not exist!
    echo Please run CMake build first.
    pause
    exit /b 1
)

echo [1/6] Copying FFmpeg video libraries (6 DLLs)...
copy /Y "%FFMPEG_BIN%\avcodec-58.dll" "%BUILD_DIR%\" >nul
copy /Y "%FFMPEG_BIN%\avformat-58.dll" "%BUILD_DIR%\" >nul
copy /Y "%FFMPEG_BIN%\avutil-56.dll" "%BUILD_DIR%\" >nul
copy /Y "%FFMPEG_BIN%\swresample-3.dll" "%BUILD_DIR%\" >nul
copy /Y "%FFMPEG_BIN%\swscale-5.dll" "%BUILD_DIR%\" >nul
copy /Y "%FFMPEG_BIN%\libx264-165.dll" "%BUILD_DIR%\" >nul
echo    OK - FFmpeg DLLs copied

echo.
echo [2/6] Copying SDL2 video device library...
copy /Y "%SDL2_LIB%\SDL2.dll" "%BUILD_DIR%\" >nul
echo    OK - SDL2.dll copied

echo.
echo [3/6] Copying MSYS2 MinGW64 runtime libraries...
copy /Y "%MSYS2_BIN%\libwinpthread-1.dll" "%BUILD_DIR%\" >nul
copy /Y "%MSYS2_BIN%\libgcc_s_seh-1.dll" "%BUILD_DIR%\" >nul
copy /Y "%MSYS2_BIN%\libstdc++-6.dll" "%BUILD_DIR%\" >nul
copy /Y "%MSYS2_BIN%\libiconv-2.dll" "%BUILD_DIR%\" >nul
echo    OK - MinGW runtime DLLs copied

echo.
echo [4/6] Running windeployqt to deploy Qt dependencies...
echo    (This may take 1-2 minutes, please wait...)
cd /d "%BUILD_DIR%"
"%QT_BIN%\windeployqt.exe" --qmldir "%QML_SOURCE%" belt_control_system.exe >nul 2>&1
if errorlevel 1 (
    echo    WARNING - windeployqt had errors, but continuing...
) else (
    echo    OK - Qt dependencies deployed
)

echo.
echo [5/6] Verifying critical DLL files...
set "MISSING=0"
if not exist "%BUILD_DIR%\Qt6Core.dll" (
    echo    MISSING: Qt6Core.dll
    set "MISSING=1"
)
if not exist "%BUILD_DIR%\Qt6Gui.dll" (
    echo    MISSING: Qt6Gui.dll
    set "MISSING=1"
)
if not exist "%BUILD_DIR%\Qt6Quick.dll" (
    echo    MISSING: Qt6Quick.dll
    set "MISSING=1"
)
if not exist "%BUILD_DIR%\avcodec-58.dll" (
    echo    MISSING: avcodec-58.dll
    set "MISSING=1"
)
if not exist "%BUILD_DIR%\SDL2.dll" (
    echo    MISSING: SDL2.dll
    set "MISSING=1"
)
if not exist "%BUILD_DIR%\libiconv-2.dll" (
    echo    MISSING: libiconv-2.dll
    set "MISSING=1"
)

if "%MISSING%"=="0" (
    echo    OK - All critical DLLs are in place
) else (
    echo    WARNING - Missing DLLs detected, application may not run properly
)

echo.
echo [6/6] Verifying QML modules...
if exist "%BUILD_DIR%\qml\QtQuick" (
    echo    OK - QtQuick QML module deployed
) else (
    echo    MISSING: QtQuick QML module
)
if exist "%BUILD_DIR%\qml\Qt5Compat" (
    echo    OK - Qt5Compat QML module deployed
) else (
    echo    MISSING: Qt5Compat QML module
)

echo.
echo ========================================
echo Deployment complete!
echo ========================================
echo.
echo Deploy location: %BUILD_DIR%
echo Executable: belt_control_system.exe
echo.
echo Statistics:
for /f %%A in ('dir /b "%BUILD_DIR%\*.dll" 2^>nul ^| find /c /v ""') do echo    DLL files: %%A
if exist "%BUILD_DIR%\qml" (
    for /f %%A in ('dir /b /ad "%BUILD_DIR%\qml" 2^>nul ^| find /c /v ""') do echo    QML modules: %%A
)
echo.

endlocal
