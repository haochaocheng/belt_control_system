@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

echo =========================================
echo RK3588 完整部署流程（一键执行）
echo =========================================
echo.

cd /d %~dp0

REM 步骤 1: 构建运行时镜像
echo 步骤 1/5: 构建运行时 Docker 镜像...
echo.
call build-runtime.bat
if %ERRORLEVEL% NEQ 0 (
    echo ❌ 构建失败
    pause
    exit /b 1
)

echo.
echo =========================================
echo 步骤 2/5: 保存 Docker 镜像到文件...
echo =========================================
docker save belt-control-rk3588:runtime -o belt-control-runtime.tar
if %ERRORLEVEL% EQU 0 (
    echo ✅ 镜像已保存: belt-control-runtime.tar
    for %%A in (belt-control-runtime.tar) do echo    文件大小: %%~zA 字节
) else (
    echo ❌ 保存失败
    pause
    exit /b 1
)

echo.
echo =========================================
echo 步骤 3/5: 传输镜像到工控机...
echo =========================================
echo 正在上传镜像文件（这可能需要几分钟）...
scp belt-control-runtime.tar pi@192.168.10.170:/tmp/
if %ERRORLEVEL% EQU 0 (
    echo ✅ 镜像传输完成
) else (
    echo ❌ 传输失败
    pause
    exit /b 1
)

echo.
echo =========================================
echo 步骤 4/5: 传输部署脚本...
echo =========================================
scp deploy.sh docker-compose.yml pi@192.168.10.170:/tmp/
echo ✅ 部署文件已传输

echo.
echo =========================================
echo 步骤 5/5: 在工控机上执行部署...
echo =========================================
ssh pi@192.168.10.170 "chmod +x /tmp/deploy.sh && sudo /tmp/deploy.sh"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo =========================================
    echo ✅ 部署成功完成！
    echo =========================================
    echo.
    echo 系统已在工控机上启动。
    echo.
    echo 常用命令:
    echo   查看状态: ssh pi@192.168.10.170 "cd /opt/belt_control && docker-compose ps"
    echo   查看日志: ssh pi@192.168.10.170 "cd /opt/belt_control && docker-compose logs -f"
    echo   重启服务: ssh pi@192.168.10.170 "cd /opt/belt_control && docker-compose restart"
    echo   停止服务: ssh pi@192.168.10.170 "cd /opt/belt_control && docker-compose down"
    echo.
    echo 批量部署:
    echo   将 belt-control-runtime.tar 复制到其他工控机
    echo   运行: scp deploy.sh docker-compose.yml belt-control-runtime.tar pi@新IP:/tmp/
    echo   执行: ssh pi@新IP "sudo /tmp/deploy.sh"
    echo.
) else (
    echo.
    echo ❌ 部署失败，请检查错误信息
    echo.
)

pause
