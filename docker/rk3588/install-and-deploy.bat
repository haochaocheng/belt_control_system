@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo =========================================
echo 一键安装 Docker 并部署（远程）
echo =========================================
echo.

set REMOTE_HOST=192.168.10.170
set REMOTE_USER=pi
set REMOTE_PASS=pi

echo 目标工控机: %REMOTE_USER%@%REMOTE_HOST%
echo.

REM 检查是否可以连接
echo 检查工控机连接...
ping -n 1 %REMOTE_HOST% >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ❌ 无法连接到 %REMOTE_HOST%
    echo    请检查网络连接和IP地址
    pause
    exit /b 1
)
echo ✅ 工控机连接正常
echo.

echo =========================================
echo 步骤 1/3: 安装 Docker 环境
echo =========================================
echo.

REM 传输安装脚本
echo 正在传输安装脚本...
scp install-docker.sh %REMOTE_USER%@%REMOTE_HOST%:/tmp/
if %ERRORLEVEL% NEQ 0 (
    echo ❌ 文件传输失败
    pause
    exit /b 1
)
echo ✅ 脚本已传输
echo.

REM 执行安装
echo 开始安装 Docker（这可能需要几分钟）...
echo.
ssh %REMOTE_USER%@%REMOTE_HOST% "chmod +x /tmp/install-docker.sh && sudo /tmp/install-docker.sh"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Docker 安装失败
    echo    请检查上面的错误信息
    pause
    exit /b 1
)

echo.
echo ✅ Docker 环境安装完成！
echo.

REM 等待用户确认
echo 按任意键继续部署应用...
pause >nul

echo.
echo =========================================
echo 步骤 2/3: 构建运行时镜像
echo =========================================
echo.

cd /d %~dp0

REM 调用构建脚本
call build-runtime.bat
if %ERRORLEVEL% NEQ 0 (
    echo ❌ 镜像构建失败
    pause
    exit /b 1
)

echo.
echo =========================================
echo 步骤 3/3: 部署到工控机
echo =========================================
echo.

REM 保存镜像
echo 正在保存镜像...
docker save belt-control-rk3588:runtime -o belt-control-runtime.tar
if %ERRORLEVEL% NEQ 0 (
    echo ❌ 镜像保存失败
    pause
    exit /b 1
)
echo ✅ 镜像已保存
echo.

REM 传输文件到工控机
echo 正在传输文件到工控机（这可能需要几分钟）...
echo   镜像文件大小:
for %%A in (belt-control-runtime.tar) do echo   %%~zA 字节 (约 %%~zA/1048576 MB)

scp belt-control-runtime.tar deploy.sh docker-compose.yml %REMOTE_USER%@%REMOTE_HOST%:/tmp/
if %ERRORLEVEL% NEQ 0 (
    echo ❌ 文件传输失败
    pause
    exit /b 1
)
echo ✅ 文件传输完成
echo.

REM 执行部署
echo 正在部署应用...
ssh %REMOTE_USER%@%REMOTE_HOST% "chmod +x /tmp/deploy.sh && sudo /tmp/deploy.sh"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo =========================================
    echo ✅ 安装和部署全部完成！
    echo =========================================
    echo.
    echo 工控机信息: %REMOTE_USER%@%REMOTE_HOST%
    echo.
    echo 常用管理命令:
    echo   查看状态: ssh %REMOTE_USER%@%REMOTE_HOST% "cd /opt/belt_control && docker-compose ps"
    echo   查看日志: ssh %REMOTE_USER%@%REMOTE_HOST% "cd /opt/belt_control && docker-compose logs -f"
    echo   重启服务: ssh %REMOTE_USER%@%REMOTE_HOST% "cd /opt/belt_control && docker-compose restart"
    echo   停止服务: ssh %REMOTE_USER%@%REMOTE_HOST% "cd /opt/belt_control && docker-compose down"
    echo.
    echo 本地快捷查看:
    echo   创建了 view-status.bat 和 view-logs.bat 快捷脚本
    echo.
) else (
    echo.
    echo ❌ 部署失败
    echo    请检查上面的错误信息
    echo.
)

pause
