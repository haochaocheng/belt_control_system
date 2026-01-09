# ✅ 2026-01-09 12:00 [简化 GDB 脚本] 避免语法问题的简化版本
# PowerShell 7 UTF-8 强制配置
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

param([string]$Device = "188")

$ProjectRoot = $PSScriptRoot | Split-Path | Split-Path
$DeviceUser = "linaro"
$DeviceIP = "192.168.10.188"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "GDB Crash Analysis (Simplified)" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check container
Write-Host "[1/3] Checking container..." -ForegroundColor Green
$containerStatus = ssh -o StrictHostKeyChecking=no "$DeviceUser@$DeviceIP" 'docker ps --filter name=belt-control-app --format "{{.Status}}"'
Write-Host "  Container status: $containerStatus" -ForegroundColor Gray
Write-Host ""

# Step 2: Install GDB if needed
Write-Host "[2/3] Checking GDB..." -ForegroundColor Green
$checkGdb = 'docker exec belt-control-app which gdb'
ssh -o StrictHostKeyChecking=no "$DeviceUser@$DeviceIP" "$checkGdb" 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "  Installing GDB..." -ForegroundColor Gray
    $installGdb = "docker exec belt-control-app bash -c 'apt update -qq && apt install -y -qq gdb'"
    ssh -o StrictHostKeyChecking=no "$DeviceUser@$DeviceIP" "$installGdb" 2>&1 | Out-Null
    Write-Host "  GDB installed" -ForegroundColor Green
} else {
    Write-Host "  GDB ready" -ForegroundColor Green
}
Write-Host ""

# Step 3: Run program under GDB and wait for crash
Write-Host "[3/3] Running GDB (30 seconds timeout)..." -ForegroundColor Green
Write-Host ""
Write-Host "IMPORTANT: You need to manually trigger video call to reproduce crash!" -ForegroundColor Yellow
Write-Host ""

$gdbCmd = "docker exec -it belt-control-app bash -c 'ulimit -c unlimited && timeout 60 gdb -batch -ex run -ex bt -ex quit /app/belt_control_system'"
ssh -t -o StrictHostKeyChecking=no "$DeviceUser@$DeviceIP" "$gdbCmd"

Write-Host ""
Write-Host "================================================" -ForegroundColor Green
Write-Host "Done" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
