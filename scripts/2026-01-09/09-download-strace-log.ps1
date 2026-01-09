# ✅ 2026-01-09 12:10 [Strace 日志下载] 下载和分析 strace 日志
# PowerShell 7 UTF-8 强制配置
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

param([string]$Device = "188")

$ProjectRoot = $PSScriptRoot | Split-Path | Split-Path
$DeviceUser = "linaro"
$DeviceIP = "192.168.10.188"

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Strace 日志下载和分析" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: 检查日志文件
Write-Host "[1/3] 检查 strace 日志..." -ForegroundColor Green
$checkLog = 'docker exec belt-control-app bash -c "ls -lh /tmp/strace.log 2>/dev/null || echo NO_LOG"'
$logInfo = ssh -o StrictHostKeyChecking=no "$DeviceUser@$DeviceIP" "$checkLog"

if ($logInfo -match "NO_LOG") {
    Write-Host "  ❌ 未找到 strace 日志" -ForegroundColor Red
    exit 1
}

Write-Host $logInfo
Write-Host ""

# Step 2: 下载日志
Write-Host "[2/3] 下载日志..." -ForegroundColor Green
$logDir = "$ProjectRoot\docs\log"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$localLog = "$logDir\strace_$timestamp.log"

$downloadCmd = "docker exec belt-control-app cat /tmp/strace.log"
$content = ssh -o StrictHostKeyChecking=no "$DeviceUser@$DeviceIP" "$downloadCmd"
$content | Out-File -FilePath $localLog -Encoding UTF8

Write-Host "  Done" -ForegroundColor Gray
Write-Host ""

# Step 3: 分析最后的系统调用
Write-Host "[3/3] 分析崩溃前的系统调用..." -ForegroundColor Green
Write-Host ""
Write-Host "===============================================" -ForegroundColor Yellow
Write-Host "最后 50 行系统调用" -ForegroundColor Yellow
Write-Host "===============================================" -ForegroundColor Yellow
Write-Host ""

$lines = Get-Content $localLog
$lastLines = $lines | Select-Object -Last 50
$lastLines | ForEach-Object { Write-Host $_ }

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "分析完成" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "完整日志已保存到:" -ForegroundColor Cyan
Write-Host "  $localLog" -ForegroundColor White
Write-Host ""
Write-Host "关键信息：" -ForegroundColor Yellow
Write-Host "  - 查看最后的 write() 调用（日志打印）" -ForegroundColor Gray
Write-Host "  - 查看 SIGSEGV 信号" -ForegroundColor Gray
Write-Host "  - 查看崩溃前的内存操作（mmap, munmap）" -ForegroundColor Gray
Write-Host ""
