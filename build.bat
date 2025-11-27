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
if not exist build mkdir build
cd build

echo.
echo Cleaning QML cache...
if exist src\qml\qml_module_qmltyperegistrations.cpp del src\qml\qml_module_qmltyperegistrations.cpp

echo Building...
"%CMAKE_EXE%" --build . --config Release --clean-first
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
