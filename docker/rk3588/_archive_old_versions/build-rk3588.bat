@echo off
setlocal enabledelayedexpansion

echo ========================================
echo RK3588 交叉编译构建脚本
echo ========================================
echo.

REM 设置路径
set "CROSS_TOOLS_DIR=F:\新建文件夹"
set "PROJECT_DIR=%~dp0.."
set "DOCKER_DIR=%PROJECT_DIR%\docker\rk3588"
set "BUILD_DIR=%PROJECT_DIR%\build_rk3588"
set "OUTPUT_DIR=%PROJECT_DIR%\output_rk3588"

echo 项目目录: %PROJECT_DIR%
echo 交叉工具目录: %CROSS_TOOLS_DIR%
echo 构建目录: %BUILD_DIR%
echo 输出目录: %OUTPUT_DIR%
echo.

REM 检查Docker是否安装
docker --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ❌ 错误: Docker未安装或未运行
    echo    请先安装Docker Desktop for Windows
    pause
    exit /b 1
)

echo ✅ Docker已就绪
echo.

REM 步骤1: 准备交叉编译工具
echo ========================================
echo 步骤 1/5: 准备交叉编译工具
echo ========================================

if not exist "%DOCKER_DIR%\sysroot" (
    echo 解压 RK3588 sysroot...
    if exist "%CROSS_TOOLS_DIR%\my_piroot.tar" (
        mkdir "%DOCKER_DIR%\sysroot"
        tar -xf "%CROSS_TOOLS_DIR%\my_piroot.tar" -C "%DOCKER_DIR%\sysroot"
        echo ✅ Sysroot解压完成
    ) else (
        echo ❌ 错误: 找不到 my_piroot.tar
        echo    请检查路径: %CROSS_TOOLS_DIR%\my_piroot.tar
        pause
        exit /b 1
    )
) else (
    echo ✅ Sysroot已存在
)

if not exist "%DOCKER_DIR%\qt-raspi" (
    echo 解压 Qt for RK3588...
    if exist "%CROSS_TOOLS_DIR%\qt-raspi.tar.xz" (
        tar -xf "%CROSS_TOOLS_DIR%\qt-raspi.tar.xz" -C "%DOCKER_DIR%"
        echo ✅ Qt Target解压完成
    ) else (
        echo ❌ 错误: 找不到 qt-raspi.tar.xz
        pause
        exit /b 1
    )
) else (
    echo ✅ Qt Target已存在
)

if not exist "%DOCKER_DIR%\qt-host" (
    echo 解压 Qt Host...
    if exist "%CROSS_TOOLS_DIR%\qt-host.tar.xz" (
        tar -xf "%CROSS_TOOLS_DIR%\qt-host.tar.xz" -C "%DOCKER_DIR%"
        echo ✅ Qt Host解压完成
    ) else (
        echo ❌ 错误: 找不到 qt-host.tar.xz
        pause
        exit /b 1
    )
) else (
    echo ✅ Qt Host已存在
)

echo.
echo ========================================
echo 步骤 2/5: 构建Docker镜像
echo ========================================

docker build -t belt-control-rk3588:latest "%DOCKER_DIR%"
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Docker镜像构建失败
    pause
    exit /b 1
)

echo ✅ Docker镜像构建完成
echo.

REM 步骤3: 准备Sherpa-ONNX ARM64库
echo ========================================
echo 步骤 3/5: 准备Sherpa-ONNX ARM64库
echo ========================================

if not exist "%PROJECT_DIR%\libs\sherpa-onnx-v1.12.9-linux-aarch64-shared" (
    if exist "%PROJECT_DIR%\libs\sherpa-onnx-v1.12.9-linux-aarch64-shared-cpu.tar.bz2" (
        echo 解压Sherpa-ONNX ARM64库...
        cd /d "%PROJECT_DIR%\libs"
        tar -xf sherpa-onnx-v1.12.9-linux-aarch64-shared-cpu.tar.bz2
        ren sherpa-onnx-v1.12.9-linux-aarch64-shared-cpu sherpa-onnx-v1.12.9-linux-aarch64-shared
        cd /d "%PROJECT_DIR%"
        echo ✅ Sherpa-ONNX ARM64库已准备
    ) else (
        echo ❌ 警告: 找不到 Sherpa-ONNX ARM64库
        echo    TTS功能将被禁用
    )
) else (
    echo ✅ Sherpa-ONNX ARM64库已存在
)

echo.

REM 步骤4: 交叉编译
echo ========================================
echo 步骤 4/5: 交叉编译
echo ========================================

REM 创建构建目录
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"

REM 运行Docker容器进行交叉编译
REM 使用 Qt 自带的 toolchain 文件，通过 QT_CHAINLOAD_TOOLCHAIN_FILE 加载我们的 toolchain
docker run --rm ^
    -v "%PROJECT_DIR%:/workspace/belt_control_system" ^
    -v "%DOCKER_DIR%\qt-host:/opt/qt-host:ro" ^
    -v "%DOCKER_DIR%\qt-raspi:/opt/qt-raspi:ro" ^
    -v "%DOCKER_DIR%\sysroot:/opt/sysroot:ro" ^
    -v "%DOCKER_DIR%\rk3588-libs:/opt/rk3588-libs:ro" ^
    -e QT_HOST_PATH=/opt/qt-host ^
    -e QT_TARGET_PATH=/opt/qt-raspi ^
    -e SYSROOT=/opt/sysroot/pi-root ^
    -w /workspace/belt_control_system/build_rk3588 ^
    belt-control-rk3588:latest ^
    bash -c "cmake -DCMAKE_TOOLCHAIN_FILE=/opt/qt-raspi/lib/cmake/Qt6/qt.toolchain.cmake -DQT_CHAINLOAD_TOOLCHAIN_FILE=../docker/rk3588/toolchain-rk3588.cmake -DCMAKE_BUILD_TYPE=Release -DENABLE_SHERPA_ONNX=ON .. && make -j4"

if %ERRORLEVEL% NEQ 0 (
    echo ❌ 交叉编译失败
    pause
    exit /b 1
)

echo ✅ 交叉编译完成
echo.

REM 步骤5: 打包输出
echo ========================================
echo 步骤 5/5: 打包输出
echo ========================================

if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"

REM 复制可执行文件
copy "%BUILD_DIR%\src\main\belt_control_system" "%OUTPUT_DIR%\"
copy "%BUILD_DIR%\config.ini" "%OUTPUT_DIR%\" 2>nul

REM 复制依赖库
xcopy /E /I /Y "%PROJECT_DIR%\libs\sherpa-onnx-v1.12.9-linux-aarch64-shared\lib" "%OUTPUT_DIR%\lib"
xcopy /E /I /Y "%PROJECT_DIR%\libs\tts_models" "%OUTPUT_DIR%\tts_models"

REM 创建部署脚本
echo #!/bin/bash > "%OUTPUT_DIR%\run.sh"
echo export LD_LIBRARY_PATH=./lib:$LD_LIBRARY_PATH >> "%OUTPUT_DIR%\run.sh"
echo ./belt_control_system >> "%OUTPUT_DIR%\run.sh"

echo ✅ 输出文件已打包到: %OUTPUT_DIR%
echo.

echo ========================================
echo 🎉 构建完成！
echo ========================================
echo.
echo 输出目录: %OUTPUT_DIR%
echo.
echo 下一步: 将 %OUTPUT_DIR% 目录复制到RK3588设备
echo.
pause
