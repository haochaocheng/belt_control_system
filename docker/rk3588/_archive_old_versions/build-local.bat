@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo =========================================
echo RK3588 依赖库编译 (使用本地源码)
echo =========================================
echo.

cd /d %~dp0

echo 开始编译...
echo.

docker run --rm ^
  -v "e:/2025/3_gongkongji/belt_control_system:/workspace/belt_control_system" ^
  -v "c:/video_deps:/workspace/video_deps:ro" ^
  -v "%~dp0qt-host:/opt/qt-host:ro" ^
  -v "%~dp0qt-raspi:/opt/qt-raspi:ro" ^
  -v "%~dp0sysroot:/opt/sysroot:ro" ^
  -v "%~dp0rk3588-libs:/opt/rk3588-libs" ^
  belt-control-rk3588:latest ^
  bash /workspace/belt_control_system/docker/rk3588/build-dependencies-local.sh

if %ERRORLEVEL% EQU 0 (
    echo.
    echo =========================================
    echo ✅ 编译完成！
    echo =========================================
    echo.
    echo 编译的库位于: %~dp0rk3588-libs\lib
    echo.
) else (
    echo.
    echo ❌ 编译失败
    echo.
)

pause
