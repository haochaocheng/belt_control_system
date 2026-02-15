#Requires -Version 5.1
<#
.SYNOPSIS
    整理PaddleSpeech模型到统一目录
.DESCRIPTION
    将Docker容器中下载的PaddleSpeech模型复制到本地统一目录
.EXAMPLE
    .\11-organize-paddlespeech-models.ps1
.NOTES
    2026-02-15 14:00: 创建 - 整理模型目录
#>

$ErrorActionPreference = "Stop"

# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# ============================================================
# 配置
# ============================================================
$ProjectRoot = "E:\2025\3_gongkongji\belt_control_system"
$TargetDir = Join-Path $ProjectRoot "tts_models\paddlespeech_all"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  整理PaddleSpeech模型" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 创建目标目录
# ============================================================
Write-Host "[1/3] 准备目标目录..." -ForegroundColor Yellow

if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    Write-Host "  ✅ 创建目录: $TargetDir" -ForegroundColor Green
} else {
    Write-Host "  ✅ 目录已存在: $TargetDir" -ForegroundColor Green
}

Write-Host ""

# ============================================================
# 从Docker容器复制模型
# ============================================================
Write-Host "[2/3] 从Docker容器复制模型..." -ForegroundColor Yellow
Write-Host ""

# 创建临时容器并复制模型
$containerScript = @"
# 检查模型目录
if [ -d /root/.paddlespeech ]; then
    echo '  📂 找到PaddleSpeech模型目录'

    # 显示目录结构
    echo '  📋 模型目录结构:'
    du -sh /root/.paddlespeech/* 2>/dev/null || echo '  ⚠️  目录为空'

    # 复制到输出目录
    echo '  📦 复制模型...'
    cp -r /root/.paddlespeech/* /output/ 2>/dev/null || echo '  ⚠️  复制失败'

    echo '  ✅ 复制完成'
else
    echo '  ❌ 未找到模型目录'
    exit 1
fi
"@

try {
    Write-Host "  🐳 启动Docker容器..." -ForegroundColor Cyan

    & docker run --rm `
        -v "${TargetDir}:/output" `
        python:3.11-slim `
        bash -c $containerScript

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "  ❌ 复制失败" -ForegroundColor Red
        Write-Host "  💡 提示: 模型可能在Docker容器的缓存中，需要重新下载" -ForegroundColor Yellow
        exit 1
    }

    Write-Host ""
    Write-Host "  ✅ 模型复制完成" -ForegroundColor Green

} catch {
    Write-Host ""
    Write-Host "  ❌ 错误: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ============================================================
# 统计模型大小
# ============================================================
Write-Host "[3/3] 统计模型信息..." -ForegroundColor Yellow
Write-Host ""

if (Test-Path $TargetDir) {
    $totalSize = (Get-ChildItem $TargetDir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB

    Write-Host "  📦 模型总大小: $([math]::Round($totalSize, 1)) MB" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "  📋 模型列表:" -ForegroundColor Cyan
    Get-ChildItem $TargetDir -Directory | ForEach-Object {
        $modelSize = (Get-ChildItem $_.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
        Write-Host "     - $($_.Name): $([math]::Round($modelSize, 1)) MB" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ 整理完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "📁 模型目录: $TargetDir" -ForegroundColor Cyan
Write-Host ""
