@echo off
REM ============================================================================
REM Video Call Dependencies Setup Script for Windows
REM ============================================================================
REM This script prepares the environment for building PJSIP with video support
REM
REM Requirements:
REM   - MSYS2 installed at C:\msys64
REM   - Git installed
REM   - Visual Studio 2019/2022 with C++ development tools
REM
REM Dependencies to download:
REM   1. x264 (H.264 encoder)
REM   2. FFmpeg 6.0 (video codec framework)
REM   3. SDL2 2.28.5 (video rendering)
REM
REM ============================================================================

echo ========================================
echo Video Dependencies Setup for Windows
echo ========================================
echo.

REM Check if running with administrator privileges
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo WARNING: Not running as administrator
    echo Some operations may fail
    echo.
)

REM Set up directories
set DEPS_ROOT=C:\video_deps
set X264_ROOT=%DEPS_ROOT%\x264
set FFMPEG_ROOT=%DEPS_ROOT%\ffmpeg
set SDL2_ROOT=%DEPS_ROOT%\SDL2

echo Creating dependency directories...
if not exist "%DEPS_ROOT%" mkdir "%DEPS_ROOT%"
cd /d "%DEPS_ROOT%"

REM ============================================================================
REM 1. Download x264
REM ============================================================================
echo.
echo ========================================
echo 1. Downloading x264...
echo ========================================
if not exist "%DEPS_ROOT%\x264_src" (
    echo Cloning x264 from VideoLAN...
    git clone --depth 1 https://code.videolan.org/videolan/x264.git x264_src
    if %errorLevel% NEQ 0 (
        echo ERROR: Failed to clone x264
        pause
        exit /b 1
    )
    cd x264_src
    git checkout stable
    cd ..
    echo x264 downloaded successfully!
) else (
    echo x264 source already exists, skipping download
)

REM ============================================================================
REM 2. Download FFmpeg 6.0
REM ============================================================================
echo.
echo ========================================
echo 2. Downloading FFmpeg 6.0...
echo ========================================
if not exist "%DEPS_ROOT%\ffmpeg-6.0.tar.xz" (
    echo Downloading FFmpeg 6.0 from ffmpeg.org...
    curl -L -o ffmpeg-6.0.tar.xz https://ffmpeg.org/releases/ffmpeg-6.0.tar.xz
    if %errorLevel% NEQ 0 (
        echo ERROR: Failed to download FFmpeg
        echo Please download manually from: https://ffmpeg.org/releases/ffmpeg-6.0.tar.xz
        pause
        exit /b 1
    )
    echo FFmpeg downloaded successfully!
) else (
    echo FFmpeg archive already exists, skipping download
)

if not exist "%DEPS_ROOT%\ffmpeg-6.0" (
    echo Extracting FFmpeg...
    tar -xf ffmpeg-6.0.tar.xz
    if %errorLevel% NEQ 0 (
        echo ERROR: Failed to extract FFmpeg
        echo Please ensure tar is available in PATH
        pause
        exit /b 1
    )
    echo FFmpeg extracted successfully!
) else (
    echo FFmpeg source already extracted, skipping
)

REM ============================================================================
REM 3. Download SDL2 2.28.5
REM ============================================================================
echo.
echo ========================================
echo 3. Downloading SDL2 2.28.5...
echo ========================================
if not exist "%DEPS_ROOT%\SDL2-devel-2.28.5-VC.zip" (
    echo Downloading SDL2 2.28.5 precompiled binaries...
    curl -L -o SDL2-devel-2.28.5-VC.zip https://github.com/libsdl-org/SDL/releases/download/release-2.28.5/SDL2-devel-2.28.5-VC.zip
    if %errorLevel% NEQ 0 (
        echo ERROR: Failed to download SDL2
        echo Please download manually from: https://github.com/libsdl-org/SDL/releases/tag/release-2.28.5
        pause
        exit /b 1
    )
    echo SDL2 downloaded successfully!
) else (
    echo SDL2 archive already exists, skipping download
)

if not exist "%DEPS_ROOT%\SDL2-2.28.5" (
    echo Extracting SDL2...
    tar -xf SDL2-devel-2.28.5-VC.zip
    if %errorLevel% NEQ 0 (
        echo ERROR: Failed to extract SDL2
        pause
        exit /b 1
    )
    echo SDL2 extracted successfully!
) else (
    echo SDL2 already extracted, skipping
)

REM ============================================================================
REM 4. Check MSYS2 installation
REM ============================================================================
echo.
echo ========================================
echo 4. Checking MSYS2 installation...
echo ========================================
if not exist "C:\msys64\msys2_shell.cmd" (
    echo ERROR: MSYS2 not found at C:\msys64
    echo.
    echo Please install MSYS2 from: https://www.msys2.org/
    echo.
    echo After installation, run these commands in MSYS2 shell:
    echo   pacman -Syu
    echo   pacman -S base-devel mingw-w64-x86_64-toolchain
    echo   pacman -S yasm nasm
    echo.
    pause
    exit /b 1
) else (
    echo MSYS2 found at C:\msys64
)

REM ============================================================================
REM Summary
REM ============================================================================
echo.
echo ========================================
echo Download Summary
echo ========================================
echo Dependencies root: %DEPS_ROOT%
echo.
echo Downloaded components:
if exist "%DEPS_ROOT%\x264_src" (
    echo   [OK] x264 source
) else (
    echo   [MISSING] x264 source
)
if exist "%DEPS_ROOT%\ffmpeg-6.0" (
    echo   [OK] FFmpeg 6.0 source
) else (
    echo   [MISSING] FFmpeg 6.0 source
)
if exist "%DEPS_ROOT%\SDL2-2.28.5" (
    echo   [OK] SDL2 2.28.5 binaries
) else (
    echo   [MISSING] SDL2 2.28.5 binaries
)
echo.
echo ========================================
echo Next Steps
echo ========================================
echo 1. Ensure MSYS2 is installed and updated
echo 2. Run: scripts\build_x264_windows.sh (in MSYS2 shell)
echo 3. Run: scripts\build_ffmpeg_windows.sh (in MSYS2 shell)
echo 4. Run: scripts\build_pjsip_windows.sh (in MSYS2 shell)
echo.
echo All scripts are located in: %~dp0
echo.
pause
