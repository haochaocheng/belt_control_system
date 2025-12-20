@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo ========================================
echo RK3588 交叉编译环境一键构建
echo ========================================
echo.

REM 获取脚本目录
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

echo [1/3] 检查 Docker 环境...
docker --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ❌ 错误: Docker 未安装或未启动
    echo.
    echo 请确保:
    echo   1. Docker Desktop 已安装
    echo   2. Docker Desktop 正在运行
    echo   3. Docker 命令在系统 PATH 中
    echo.
    pause
    exit /b 1
)

docker --version
echo ✅ Docker 可用
echo.

echo [2/3] 检查必需文件...
if not exist "qt-host" (
    echo ❌ 错误: qt-host 目录不存在
    echo    请先解压 qt-host.tar.xz
    pause
    exit /b 1
)

if not exist "qt-raspi" (
    echo ❌ 错误: qt-raspi 目录不存在
    echo    请先解压 qt-raspi.tar.xz
    pause
    exit /b 1
)

if not exist "sysroot" (
    echo ❌ 错误: sysroot 目录不存在
    echo    请先解压 my_piroot.tar
    pause
    exit /b 1
)

echo ✅ qt-host 目录存在
echo ✅ qt-raspi 目录存在
echo ✅ sysroot 目录存在
echo.

echo [3/3] 构建 Docker 镜像...
echo 这可能需要 5-8 分钟，请耐心等待...
echo.

docker build -t belt-control-rk3588:latest .

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Docker 镜像构建失败
    echo    请检查上方错误信息
    pause
    exit /b 1
)

echo.
echo ========================================
echo ✅ Docker 镜像构建完成！
echo ========================================
echo.

docker images belt-control-rk3588:latest

echo.
echo 🎉 环境准备完成！
echo.
echo 下一步: 编译多媒体依赖库
echo    运行: build-dependencies.bat
echo.
pause
