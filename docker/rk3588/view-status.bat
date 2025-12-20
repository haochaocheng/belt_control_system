@echo off
chcp 65001 >nul

set REMOTE_HOST=192.168.10.170
set REMOTE_USER=pi

echo =========================================
echo 查看工控机运行状态
echo =========================================
echo 工控机: %REMOTE_USER%@%REMOTE_HOST%
echo.

ssh %REMOTE_USER%@%REMOTE_HOST% "cd /opt/belt_control && docker-compose ps && echo. && echo 健康检查: && docker inspect belt_control_system --format='{{.State.Health.Status}}' 2>/dev/null || echo '未配置健康检查'"

pause
