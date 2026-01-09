# ✅ 2026-01-09 12:10 [GDB Core Dump 分析] 分析崩溃后的 core 文件
# PowerShell 7 UTF-8 强制配置
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

param([string]$Device = "188")

$ProjectRoot = $PSScriptRoot | Split-Path | Split-Path
$DeviceUser = "linaro"
$DeviceIP = "192.168.10.188"

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Core Dump 分析" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: 检查 core 文件
Write-Host "[1/4] 检查 core 文件..." -ForegroundColor Green
$findCore = 'docker exec belt-control-app bash -c "ls -lh /tmp/core.* 2>/dev/null || echo NO_CORE"'
$coreFiles = ssh -o StrictHostKeyChecking=no "$DeviceUser@$DeviceIP" "$findCore"

if ($coreFiles -match "NO_CORE") {
    Write-Host "  ❌ 未找到 core 文件" -ForegroundColor Red
    Write-Host ""
    Write-Host "可能原因：" -ForegroundColor Yellow
    Write-Host "  1. 程序未崩溃" -ForegroundColor Gray
    Write-Host "  2. Core dump 未启用（运行 06-setup-core-dump.ps1）" -ForegroundColor Gray
    Write-Host "  3. Core dump 位置不对" -ForegroundColor Gray
    exit 1
}

Write-Host $coreFiles
Write-Host ""

# Step 2: 获取最新的 core 文件名
Write-Host "[2/4] 获取最新 core 文件..." -ForegroundColor Green
$getCoreFile = 'docker exec belt-control-app bash -c "ls -t /tmp/core.* 2>/dev/null | head -1"'
$coreFile = ssh -o StrictHostKeyChecking=no "$DeviceUser@$DeviceIP" "$getCoreFile"
Write-Host "  Core file: $coreFile" -ForegroundColor Gray
Write-Host ""

# Step 3: 安装 GDB（如果需要）
Write-Host "[3/4] 检查 GDB..." -ForegroundColor Green
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

# Step 4: 分析 core dump
Write-Host "[4/4] 分析 core dump..." -ForegroundColor Green
Write-Host ""
Write-Host "===============================================" -ForegroundColor Yellow
Write-Host "GDB 分析结果" -ForegroundColor Yellow
Write-Host "===============================================" -ForegroundColor Yellow
Write-Host ""

$gdbAnalysis = @"
docker exec belt-control-app bash -c 'gdb -batch -ex "bt" -ex "info registers" -ex "info locals" -ex "thread apply all bt" -ex "quit" /app/belt_control_system $coreFile 2>&1'
"@

$result = ssh -o StrictHostKeyChecking=no "$DeviceUser@$DeviceIP" "$gdbAnalysis"
Write-Host $result
Write-Host ""

# 保存结果
$logDir = "$ProjectRoot\docs\log"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$logFile = "$logDir\core_dump_$timestamp.log"

$output = "Core Dump Analysis`n"
$output += "==================`n`n"
$output += "Core file: $coreFile`n`n"
$output += "$result`n"

$output | Out-File -FilePath $logFile -Encoding UTF8

Write-Host "===============================================" -ForegroundColor Green
Write-Host "分析完成" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "详细日志已保存到:" -ForegroundColor Cyan
Write-Host "  $logFile" -ForegroundColor White
Write-Host ""
