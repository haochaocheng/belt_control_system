@echo off
setlocal

echo ========================================
echo RK3588 部署脚本
echo ========================================
echo.

set /p RK3588_IP="请输入RK3588设备IP地址: "
set /p RK3588_USER="请输入SSH用户名 [默认: root]: "
if "%RK3588_USER%"=="" set "RK3588_USER=root"

set "OUTPUT_DIR=%~dp0..\..\output_rk3588"
set "REMOTE_DIR=/opt/belt_control_system"

echo.
echo 目标设备: %RK3588_USER%@%RK3588_IP%
echo 远程目录: %REMOTE_DIR%
echo 本地目录: %OUTPUT_DIR%
echo.

REM 检查scp是否可用
where scp >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ❌ 错误: 找不到scp命令
    echo    请安装OpenSSH客户端或使用WinSCP手动复制文件
    echo.
    echo    文件位置: %OUTPUT_DIR%
    echo    目标位置: %RK3588_USER%@%RK3588_IP%:%REMOTE_DIR%
    pause
    exit /b 1
)

echo 正在部署到RK3588...
echo.

REM 创建远程目录
ssh %RK3588_USER%@%RK3588_IP% "mkdir -p %REMOTE_DIR%"

REM 复制文件
scp -r "%OUTPUT_DIR%\*" %RK3588_USER%@%RK3588_IP%:%REMOTE_DIR%/

if %ERRORLEVEL% NEQ 0 (
    echo ❌ 部署失败
    pause
    exit /b 1
)

echo ✅ 文件已复制到RK3588
echo.

REM 设置执行权限
ssh %RK3588_USER%@%RK3588_IP% "chmod +x %REMOTE_DIR%/belt_control_system && chmod +x %REMOTE_DIR%/run.sh"

echo ✅ 权限已设置
echo.

echo ========================================
echo 🎉 部署完成！
echo ========================================
echo.
echo 在RK3588上运行程序:
echo   ssh %RK3588_USER%@%RK3588_IP%
echo   cd %REMOTE_DIR%
echo   ./run.sh
echo.
pause
