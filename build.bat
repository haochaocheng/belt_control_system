@echo off
chcp 65001 >nul
echo ========================================
echo Belt Control System - Build Script
echo ========================================
echo.

REM Set Qt path
set QT_PATH=C:\Qt\6.5.3\mingw_64
set QT_TOOLS_PATH=C:\Qt\Tools

REM Check Qt exists
if not exist "%QT_PATH%\bin\qmake.exe" (
    echo Error: Qt not found at %QT_PATH%
    pause
    exit /b 1
)

echo Found Qt: %QT_PATH%

REM Find CMake
set CMAKE_EXE=
if exist "%QT_TOOLS_PATH%\CMake_64\bin\cmake.exe" (
    set CMAKE_EXE=%QT_TOOLS_PATH%\CMake_64\bin\cmake.exe
) else if exist "C:\Program Files\CMake\bin\cmake.exe" (
    set "CMAKE_EXE=C:\Program Files\CMake\bin\cmake.exe"
) else (
    echo Error: CMake not found
    pause
    exit /b 1
)

echo Found CMake: %CMAKE_EXE%

REM Setup MinGW environment
set PATH=%QT_PATH%\bin;%QT_TOOLS_PATH%\mingw1120_64\bin;%PATH%

REM Create build directory
if not exist build (
    echo Creating build directory...
    mkdir build
)

cd build

REM Check if Makefile exists, if not, configure
if not exist Makefile (
    echo Configuring project...
    REM ✅ 2026-02-08 [Phase 7.42.8]: 启用Snap7 S7协议支持
    "%CMAKE_EXE%" -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=%QT_PATH% -DCMAKE_MAKE_PROGRAM=%QT_TOOLS_PATH%\mingw1120_64\bin\mingw32-make.exe -DENABLE_SNAP7=ON ..
    if %ERRORLEVEL% NEQ 0 (
        echo Configuration failed
        cd ..
        pause
        exit /b 1
    )
)

echo.
echo Building with 32 parallel jobs...
"%CMAKE_EXE%" --build . --target belt_control_system -j32 -- VERBOSE=1
if %ERRORLEVEL% NEQ 0 (
    echo Build failed
    cd ..
    pause
    exit /b 1
)

cd ..

echo.
echo ========================================
echo Build successful!
echo ========================================
echo Running: build\bin_windows\belt_control_system.exe
echo.
build\bin_windows\belt_control_system.exe
pause
