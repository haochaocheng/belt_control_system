@echo off
setlocal enabledelayedexpansion

echo ========================================
echo RK3588 依赖库交叉编译
echo ========================================
echo.

REM 检查Docker是否运行
docker ps >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ❌ 错误: Docker未运行
    echo    请启动Docker Desktop
    pause
    exit /b 1
)

REM 检查镜像是否存在
docker images belt-control-rk3588:latest -q >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ❌ 错误: 找不到Docker镜像 belt-control-rk3588:latest
    echo    请先运行 build-rk3588.bat 构建基础镜像
    pause
    exit /b 1
)

REM 获取脚本所在目录
set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%..\.."

REM 检查build-dependencies.sh是否存在
if not exist "%SCRIPT_DIR%build-dependencies.sh" (
    echo ❌ 错误: 找不到 build-dependencies.sh
    pause
    exit /b 1
)

echo 🔧 开始编译依赖库...
echo.
echo 目标平台: ARM64 (aarch64)
echo 输出目录: /opt/rk3588-libs
echo.

REM 询问编译选项
if "%1"=="" (
    echo 可用的编译选项:
    echo   1. 编译所有库 (默认^)
    echo   2. 仅编译 OpenSSL
    echo   3. 仅编译 Opus
    echo   4. 仅编译 x264
    echo   5. 仅编译 FFmpeg
    echo   6. 仅编译 SDL2
    echo   7. 仅编译 PJSIP
    echo.
    set /p CHOICE="请选择 [1-7，默认1]: "
    if "!CHOICE!"=="" set CHOICE=1
) else (
    set CHOICE=%1
)

REM 根据选择设置构建参数
set BUILD_ARG=
if "!CHOICE!"=="2" set BUILD_ARG=openssl
if "!CHOICE!"=="3" set BUILD_ARG=opus
if "!CHOICE!"=="4" set BUILD_ARG=x264
if "!CHOICE!"=="5" set BUILD_ARG=ffmpeg
if "!CHOICE!"=="6" set BUILD_ARG=sdl2
if "!CHOICE!"=="7" set BUILD_ARG=pjsip

echo.
if "!BUILD_ARG!"=="" (
    echo 📦 编译所有依赖库...
) else (
    echo 📦 编译 !BUILD_ARG!...
)
echo.

REM 运行Docker容器执行编译
docker run --rm ^
    -v "%PROJECT_DIR%:/workspace/belt_control_system" ^
    -v "%SCRIPT_DIR%qt-host:/opt/qt-host:ro" ^
    -v "%SCRIPT_DIR%qt-raspi:/opt/qt-raspi:ro" ^
    -v "%SCRIPT_DIR%sysroot:/opt/sysroot:ro" ^
    -v "%SCRIPT_DIR%rk3588-libs:/opt/rk3588-libs" ^
    belt-control-rk3588:latest ^
    bash /workspace/belt_control_system/docker/rk3588/build-dependencies.sh !BUILD_ARG!

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ 依赖库编译失败
    pause
    exit /b 1
)

echo.
echo ========================================
echo ✅ 依赖库编译完成！
echo ========================================
echo.
echo 编译的库位于: docker\rk3588\rk3588-libs\
echo.

REM 显示编译的库文件
if exist "%SCRIPT_DIR%rk3588-libs\lib\" (
    echo 已编译的库文件:
    dir /b "%SCRIPT_DIR%rk3588-libs\lib\*.so*" 2>nul | findstr /v /c:":" >nul
    if %ERRORLEVEL% EQU 0 (
        dir /b "%SCRIPT_DIR%rk3588-libs\lib\*.so*" | findstr /n "^" | findstr /c:"[1-9]:" >nul
        if %ERRORLEVEL% EQU 0 (
            for /f %%f in ('dir /b "%SCRIPT_DIR%rk3588-libs\lib\*.so*" ^| findstr /n "^" ^| findstr /c:"[1-9]:" ^| findstr /c:"[1-9]:" ^| findstr /v /c:"[2-9][0-9]:"') do (
                set fname=%%f
                echo   !fname:*:=!
            )
        )
    )
    echo.
)

echo 💡 提示: 这些库会在编译主程序时自动包含
echo.
pause
