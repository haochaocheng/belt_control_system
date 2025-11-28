@echo off
chcp 65001 >nul
echo ========================================
echo 快速重新构建(使用 IOCP 库)
echo ========================================
echo.

set QT_PATH=C:\Qt\6.5.3\mingw_64
set QT_TOOLS_PATH=C:\Qt\Tools

REM 设置路径
set PATH=%QT_PATH%\bin;%QT_TOOLS_PATH%\mingw1120_64\bin;%PATH%

cd build

REM 检查是否存在 Makefile
if not exist Makefile (
    echo 配置项目...
    "%QT_TOOLS_PATH%\CMake_64\bin\cmake.exe" -G "MinGW Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH=%QT_PATH% -DCMAKE_MAKE_PROGRAM=%QT_TOOLS_PATH%\mingw1120_64\bin\mingw32-make.exe ..
)

echo.
echo 正在构建...
"%QT_TOOLS_PATH%\CMake_64\bin\cmake.exe" --build . --target belt_control_system -j4

if %ERRORLEVEL% NEQ 0 (
    echo 构建失败
    cd ..
    pause
    exit /b 1
)

cd ..

echo.
echo ========================================
echo 构建成功!
echo ========================================
echo.
dir build\bin_windows\belt_control_system.exe
pause
