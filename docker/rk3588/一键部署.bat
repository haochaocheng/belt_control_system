@echo off
chcp 65001 >nul
echo ========================================
echo 批量生产部署工具
echo ========================================
echo.
echo 使用说明:
echo 1. 打开 batch-deploy.ps1
echo 2. 修改 DeviceList 列表,填入所有工控机的IP地址
echo 3. 保存后运行本脚本
echo.
pause
echo.
echo 开始部署...
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0batch-deploy.ps1"
pause
