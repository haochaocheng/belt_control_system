# ✅ 2026-01-09 12:10 [Strace 追踪] 使用 strace 记录程序崩溃前的系统调用
# 优势：不需要 GDB，直接记录所有系统调用
# PowerShell 7 UTF-8 强制配置
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

param([string]$Device = "188")

$ProjectRoot = $PSScriptRoot | Split-Path | Split-Path
$DeviceUser = "linaro"
$DeviceIP = "192.168.10.188"

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Strace 系统调用追踪" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: 安装 strace
Write-Host "[1/3] 检查 strace..." -ForegroundColor Green
$checkStrace = 'docker exec belt-control-app which strace'
ssh -o StrictHostKeyChecking=no "$DeviceUser@$DeviceIP" "$checkStrace" 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "  Installing strace..." -ForegroundColor Gray
    $installStrace = "docker exec belt-control-app bash -c 'apt update -qq && apt install -y -qq strace'"
    ssh -o StrictHostKeyChecking=no "$DeviceUser@$DeviceIP" "$installStrace" 2>&1 | Out-Null
    Write-Host "  Strace installed" -ForegroundColor Green
} else {
    Write-Host "  Strace ready" -ForegroundColor Green
}
Write-Host ""

# Step 2: 停止当前程序
Write-Host "[2/3] 停止容器..." -ForegroundColor Green
ssh -o StrictHostKeyChecking=no "$DeviceUser@$DeviceIP" "docker stop belt-control-app"
Write-Host "  Done" -ForegroundColor Gray
Write-Host ""

# Step 3: 创建 strace 启动脚本
Write-Host "[3/3] 创建 strace 启动脚本..." -ForegroundColor Green

$straceScript = @'
#!/bin/bash
# 使用 strace 启动程序，记录所有系统调用
strace -f -o /tmp/strace.log -s 200 -tt /app/belt_control_system
'@

$createScript = "echo '$straceScript' | docker exec -i belt-control-app bash -c 'cat > /tmp/run_strace.sh && chmod +x /tmp/run_strace.sh'"
ssh -o StrictHostKeyChecking=no "$DeviceUser@$DeviceIP" "$createScript"

Write-Host "  Done" -ForegroundColor Gray
Write-Host ""

Write-Host "===============================================" -ForegroundColor Yellow
Write-Host "下一步操作：" -ForegroundColor Yellow
Write-Host "===============================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. 手动启动容器并运行 strace：" -ForegroundColor White
Write-Host "   docker start belt-control-app" -ForegroundColor Cyan
Write-Host "   docker exec belt-control-app /tmp/run_strace.sh" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. 触发视频通话，等待崩溃" -ForegroundColor White
Write-Host ""
Write-Host "3. 崩溃后，查看 strace 日志：" -ForegroundColor White
Write-Host "   docker exec belt-control-app tail -200 /tmp/strace.log" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. 下载日志到本地：" -ForegroundColor White
Write-Host "   .\scripts\2026-01-09\09-download-strace-log.ps1 $Device" -ForegroundColor Cyan
Write-Host ""
