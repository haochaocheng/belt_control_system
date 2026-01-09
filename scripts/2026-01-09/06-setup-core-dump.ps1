# ✅ 2026-01-09 12:10 [GDB Core Dump 分析] 崩溃后获取 GDB 信息的完整方案
# PowerShell 7 UTF-8 强制配置
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

param([string]$Device = "188")

$DeviceUser = "linaro"
$DeviceIP = "192.168.10.188"

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Core Dump 设置和分析" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: 启用 core dump
Write-Host "[1/3] 启用 core dump..." -ForegroundColor Green
# ✅ 2026-01-09 12:15 修正 PowerShell 语法：分步执行避免复杂字符串
ssh -o StrictHostKeyChecking=no "$DeviceUser@$DeviceIP" 'docker exec belt-control-app bash -c "ulimit -c unlimited"'
ssh -o StrictHostKeyChecking=no "$DeviceUser@$DeviceIP" 'docker exec belt-control-app bash -c "echo /tmp/core.%e.%p > /proc/sys/kernel/core_pattern"'
$result = ssh -o StrictHostKeyChecking=no "$DeviceUser@$DeviceIP" 'docker exec belt-control-app bash -c "ulimit -c"'
Write-Host "  Core dump limit: $result" -ForegroundColor Gray
Write-Host ""

# Step 2: 清理旧的 core 文件
Write-Host "[2/3] 清理旧 core 文件..." -ForegroundColor Green
ssh -o StrictHostKeyChecking=no "$DeviceUser@$DeviceIP" "docker exec belt-control-app bash -c 'rm -f /tmp/core.*'"
Write-Host "  Done" -ForegroundColor Gray
Write-Host ""

# Step 3: 等待崩溃
Write-Host "[3/3] 准备就绪" -ForegroundColor Green
Write-Host ""
Write-Host "===============================================" -ForegroundColor Yellow
Write-Host "下一步操作：" -ForegroundColor Yellow
Write-Host "===============================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. 启动程序，触发视频通话" -ForegroundColor White
Write-Host "2. 等待程序崩溃" -ForegroundColor White
Write-Host "3. 运行分析脚本：" -ForegroundColor White
Write-Host "   .\scripts\2026-01-09\07-analyze-core-dump.ps1 $Device" -ForegroundColor Cyan
Write-Host ""
