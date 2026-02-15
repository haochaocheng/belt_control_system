#Requires -Version 7.0
<#
.SYNOPSIS
    下载PaddleSpeech模型文件（离线部署方案）
.DESCRIPTION
    直接从百度BOS下载模型文件，绕过Python依赖问题
.EXAMPLE
    .\01-download-paddlespeech-models-offline.ps1
.NOTES
    2026-02-15 02:35: 创建 - 离线部署方案
#>

$ErrorActionPreference = "Stop"

# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# ============================================================
# 配置
# ============================================================
$ProjectRoot = "E:\2025\3_gongkongji\belt_control_system"
$ModelsDir = Join-Path $ProjectRoot "libs\tts_models\paddlespeech"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PaddleSpeech 模型下载工具（离线方案）" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📥 直接下载模型文件，绕过Python依赖" -ForegroundColor Yellow
Write-Host "📂 目标目录: $ModelsDir" -ForegroundColor Yellow
Write-Host ""

# ============================================================
# Step 1: 准备目录
# ============================================================
Write-Host "[1/2] 准备目标目录..." -ForegroundColor Yellow

if (-not (Test-Path $ModelsDir)) {
    New-Item -ItemType Directory -Path $ModelsDir -Force | Out-Null
    Write-Host "  ✅ 创建模型目录" -ForegroundColor Green
} else {
    Write-Host "  ✅ 模型目录已存在" -ForegroundColor Green
}

Write-Host ""

# ============================================================
# Step 2: 下载模型
# ============================================================
Write-Host "[2/2] 下载 PaddleSpeech 模型..." -ForegroundColor Yellow

# 模型列表
$models = @(
    @{
        Name = "VITS中文模型"
        Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/vits/vits_csmsc_ckpt_1.4.0.zip"
        FileName = "vits_csmsc.zip"
        ExtractDir = "vits_csmsc"
        Size = "约200MB"
    },
    @{
        Name = "FastSpeech2声学模型"
        Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_csmsc_ckpt_1.4.0.zip"
        FileName = "fastspeech2_csmsc.zip"
        ExtractDir = "fastspeech2_csmsc"
        Size = "约100MB"
    },
    @{
        Name = "PWG声码器"
        Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_csmsc_ckpt_0.5.zip"
        FileName = "pwgan_csmsc.zip"
        ExtractDir = "pwgan_csmsc"
        Size = "约50MB"
    }
)

foreach ($model in $models) {
    Write-Host "  📥 下载 $($model.Name) ($($model.Size))..." -ForegroundColor Cyan

    $zipFile = Join-Path $ModelsDir $model.FileName
    $extractPath = Join-Path $ModelsDir $model.ExtractDir

    # 检查是否已下载
    if (Test-Path $extractPath) {
        Write-Host "  ⚠️  模型已存在，跳过下载: $($model.Name)" -ForegroundColor Yellow
        Write-Host ""
        continue
    }

    try {
        # 下载
        Write-Host "  ⏳ 正在下载..." -ForegroundColor Gray
        Invoke-WebRequest -Uri $model.Url -OutFile $zipFile -UseBasicParsing -TimeoutSec 600

        Write-Host "  ✅ 下载完成" -ForegroundColor Green

        # 解压
        Write-Host "  📂 解压模型文件..." -ForegroundColor Cyan
        Expand-Archive -Path $zipFile -DestinationPath $extractPath -Force

        # 删除zip文件
        Remove-Item $zipFile -Force

        Write-Host "  ✅ 解压完成: $($model.Name)" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ 下载失败: $($model.Name)" -ForegroundColor Red
        Write-Host "  错误: $_" -ForegroundColor Red
        Write-Host ""
        Write-Host "  💡 手动下载方法：" -ForegroundColor Yellow
        Write-Host "     1. 访问: $($model.Url)" -ForegroundColor Gray
        Write-Host "     2. 下载到: $zipFile" -ForegroundColor Gray
        Write-Host "     3. 解压到: $extractPath" -ForegroundColor Gray
    }

    Write-Host ""
}

# ============================================================
# 完成
# ============================================================
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ 模型下载完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# 统计模型大小
if (Test-Path $ModelsDir) {
    $totalSize = (Get-ChildItem $ModelsDir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "📊 模型总大小: $([math]::Round($totalSize, 1)) MB" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "📋 已下载的模型:" -ForegroundColor Cyan
    Get-ChildItem $ModelsDir -Directory | ForEach-Object {
        $modelSize = (Get-ChildItem $_.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
        Write-Host "   - $($_.Name): $([math]::Round($modelSize, 1)) MB" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "🚀 下一步: 创建离线推理脚本" -ForegroundColor Yellow
Write-Host "   参考文档: docs\2026-02-15\01-PaddleSpeech离线部署完整方案.md" -ForegroundColor Gray
Write-Host ""
