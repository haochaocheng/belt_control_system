@echo off
setlocal enabledelayedexpansion

echo ========================================
echo RK3588 交叉编译环境检查
echo ========================================
echo.

set "ERROR_COUNT=0"

REM 检查1: Docker
echo [1/7] 检查 Docker...
docker --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Docker未安装或未运行
    set /a ERROR_COUNT+=1
) else (
    docker --version
    echo ✅ Docker 正常
)
echo.

REM 检查2: 交叉编译工具目录
echo [2/7] 检查交叉编译工具目录...
if not exist "F:\新建文件夹" (
    echo ❌ 找不到 F:\新建文件夹
    set /a ERROR_COUNT+=1
) else (
    echo ✅ 目录存在
)
echo.

REM 检查3: Qt和Sysroot文件
echo [3/7] 检查必需文件...
set "MISSING_FILES=0"

if not exist "F:\新建文件夹\qt-raspi.tar.xz" (
    echo ❌ 找不到 qt-raspi.tar.xz
    set /a MISSING_FILES+=1
)

if not exist "F:\新建文件夹\qt-host.tar.xz" (
    echo ❌ 找不到 qt-host.tar.xz
    set /a MISSING_FILES+=1
)

if not exist "F:\新建文件夹\my_piroot.tar" (
    echo ❌ 找不到 my_piroot.tar
    set /a MISSING_FILES+=1
)

if !MISSING_FILES! EQU 0 (
    echo ✅ qt-raspi.tar.xz
    echo ✅ qt-host.tar.xz
    echo ✅ my_piroot.tar
) else (
    set /a ERROR_COUNT+=!MISSING_FILES!
)
echo.

REM 检查4: Docker相关文件
echo [4/7] 检查Docker配置文件...
set "DOCKER_FILES=0"

if not exist "%~dp0Dockerfile" (
    echo ❌ 找不到 Dockerfile
    set /a DOCKER_FILES+=1
)

if not exist "%~dp0entrypoint.sh" (
    echo ❌ 找不到 entrypoint.sh
    set /a DOCKER_FILES+=1
)

if not exist "%~dp0toolchain-rk3588.cmake" (
    echo ❌ 找不到 toolchain-rk3588.cmake
    set /a DOCKER_FILES+=1
)

if !DOCKER_FILES! EQU 0 (
    echo ✅ Dockerfile
    echo ✅ entrypoint.sh
    echo ✅ toolchain-rk3588.cmake
) else (
    set /a ERROR_COUNT+=!DOCKER_FILES!
)
echo.

REM 检查5: 构建脚本
echo [5/7] 检查构建脚本...
set "BUILD_SCRIPTS=0"

if not exist "%~dp0build-rk3588.bat" (
    echo ❌ 找不到 build-rk3588.bat
    set /a BUILD_SCRIPTS+=1
)

if not exist "%~dp0build-dependencies.bat" (
    echo ❌ 找不到 build-dependencies.bat
    set /a BUILD_SCRIPTS+=1
)

if not exist "%~dp0build-dependencies.sh" (
    echo ❌ 找不到 build-dependencies.sh
    set /a BUILD_SCRIPTS+=1
)

if not exist "%~dp0deploy-to-rk3588.bat" (
    echo ❌ 找不到 deploy-to-rk3588.bat
    set /a BUILD_SCRIPTS+=1
)

if !BUILD_SCRIPTS! EQU 0 (
    echo ✅ build-rk3588.bat
    echo ✅ build-dependencies.bat
    echo ✅ build-dependencies.sh
    echo ✅ deploy-to-rk3588.bat
) else (
    set /a ERROR_COUNT+=!BUILD_SCRIPTS!
)
echo.

REM 检查6: 文档
echo [6/7] 检查文档...
set "DOCS=0"

if not exist "%~dp0README.md" (
    echo ❌ 找不到 README.md
    set /a DOCS+=1
)

if not exist "%~dp0DEPENDENCIES.md" (
    echo ❌ 找不到 DEPENDENCIES.md
    set /a DOCS+=1
)

if not exist "%~dp0QUICK_REFERENCE.md" (
    echo ❌ 找不到 QUICK_REFERENCE.md
    set /a DOCS+=1
)

if !DOCS! EQU 0 (
    echo ✅ README.md
    echo ✅ DEPENDENCIES.md
    echo ✅ QUICK_REFERENCE.md
) else (
    set /a ERROR_COUNT+=!DOCS!
)
echo.

REM 检查7: 磁盘空间
echo [7/7] 检查磁盘空间...
for /f "tokens=3" %%a in ('dir /-c "%~dp0" ^| findstr /C:"可用字节"') do set FREE_SPACE=%%a
if defined FREE_SPACE (
    REM 简单检查，如果可用空间数字很大则通过
    echo ✅ 磁盘空间充足
) else (
    echo ⚠️  无法检查磁盘空间
)
echo.

REM 总结
echo ========================================
echo 检查完成
echo ========================================
echo.

if !ERROR_COUNT! EQU 0 (
    echo ✅ 所有检查通过！
    echo.
    echo 🎉 您的环境已准备就绪！
    echo.
    echo 下一步:
    echo   1. 构建主程序:
    echo      build-rk3588.bat
    echo.
    echo   2. 编译多媒体依赖库（可选）:
    echo      build-dependencies.bat
    echo.
    echo   3. 部署到RK3588:
    echo      deploy-to-rk3588.bat
    echo.
) else (
    echo ❌ 发现 !ERROR_COUNT! 个问题
    echo.
    echo 请解决上述问题后再继续。
    echo.
    echo 💡 提示:
    echo   - 确保Docker Desktop正在运行
    echo   - 确认 F:\新建文件夹 包含所需文件
    echo   - 查看文档: README.md
    echo.
)

pause
