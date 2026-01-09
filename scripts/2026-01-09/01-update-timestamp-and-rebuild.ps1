# ✅ 2026-01-09 10:50 [工具脚本] 更新 PJSIP 源文件时间戳并重新编译
# 问题：Edit 工具修改文件内容但不更新时间戳，导致构建系统跳过编译
# 解决：手动更新时间戳，触发重新编译

# PowerShell 7 UTF-8 强制配置
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

param(
    [string]$Device = "188"
)

$ProjectRoot = "e:\2025\3_gongkongji\belt_control_system"
$SourceFile = "$ProjectRoot\cross-compile\src\pjproject-2.16\pjmedia\src\pjmedia-codec\ffmpeg_vid_codecs.c"

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "更新时间戳并重新编译" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: 检查源文件是否存在
if (-not (Test-Path $SourceFile)) {
    Write-Host "❌ 源文件不存在: $SourceFile" -ForegroundColor Red
    exit 1
}

# Step 2: 显示当前时间戳
$oldTimestamp = (Get-Item $SourceFile).LastWriteTime
Write-Host "[1/3] 当前时间戳: $($oldTimestamp.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Yellow

# Step 3: 更新时间戳
(Get-Item $SourceFile).LastWriteTime = Get-Date
$newTimestamp = (Get-Item $SourceFile).LastWriteTime
Write-Host "      新时间戳:   $($newTimestamp.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Green
Write-Host ""

# Step 4: 调用完整编译脚本
Write-Host "[2/3] 开始重新编译..." -ForegroundColor Yellow
Write-Host ""

Set-Location $ProjectRoot
& ".\build-ubuntu24-apt.ps1" $Device

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ 编译失败" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host "✅ 完成！" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "[3/3] 下一步: 查看日志验证版本号" -ForegroundColor Yellow
Write-Host "      ssh pi@192.168.10.$Device 'docker logs -f belt-control-latest | grep \"STARTUP-VERSION\\|CODE-VERSION\"'" -ForegroundColor White
Write-Host ""
