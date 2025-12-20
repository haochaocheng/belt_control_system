@echo off
chcp 65001 >nul

set REMOTE_HOST=192.168.10.170
set REMOTE_USER=pi

echo =========================================
echo 查看工控机实时日志
echo =========================================
echo 工控机: %REMOTE_USER%@%REMOTE_HOST%
echo 按 Ctrl+C 退出
echo.

ssh %REMOTE_USER%@%REMOTE_HOST% "cd /opt/belt_control && docker-compose logs -f --tail=50"
