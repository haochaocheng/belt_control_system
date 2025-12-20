@echo off
REM ========================================
REM 使用 MSVC 编译 Sherpa-ONNX TTS 服务
REM ========================================

echo ====================================
echo 检测 Visual Studio 环境
echo ====================================

REM 尝试查找 Visual Studio 2022
if exist "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat" (
    set VS_PATH=C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvarsall.bat
    goto :found
)

REM 尝试查找 Visual Studio 2019
if exist "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvarsall.bat" (
    set VS_PATH=C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvarsall.bat
    goto :found
)

echo ❌ 未找到 Visual Studio 安装
echo 请确保已安装 Visual Studio 2019 或 2022
echo 下载地址: https://visualstudio.microsoft.com/downloads/
pause
exit /b 1

:found
echo ✅ 找到 Visual Studio: %VS_PATH%

REM 设置 MSVC 环境变量（x64）
call "%VS_PATH%" x64

echo.
echo ====================================
echo 配置 CMake（MSVC x64）
echo ====================================

REM 创建构建目录
if not exist build-msvc mkdir build-msvc
cd build-msvc

REM 配置 CMake
cmake .. -G "Visual Studio 17 2022" -A x64 -DCMAKE_BUILD_TYPE=Release

if %ERRORLEVEL% NEQ 0 (
    echo ❌ CMake 配置失败
    pause
    exit /b 1
)

echo.
echo ====================================
echo 编译项目（Release）
echo ====================================

cmake --build . --config Release -j4

if %ERRORLEVEL% NEQ 0 (
    echo ❌ 编译失败
    pause
    exit /b 1
)

echo.
echo ====================================
echo ✅ 编译成功！
echo ====================================
echo 可执行文件位置: build-msvc\Release\sherpa_tts_service.exe
echo.

cd ..
pause
