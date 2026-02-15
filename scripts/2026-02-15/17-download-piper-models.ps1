#Requires -Version 5.1
<#
.SYNOPSIS
    下载Piper TTS模型（性能引擎）
.DESCRIPTION
    从Hugging Face下载Piper TTS中文模型
    包含ONNX模型和配置文件
.EXAMPLE
    .\17-download-piper-models.ps1
.NOTES
    2026-02-15 15:50: 创建 - 下载Piper TTS模型
#>

$ErrorActionPreference = "Stop"

# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# ============================================================
# 配置
# ============================================================
$ProjectRoot = "E:\2025\3_gongkongji\belt_control_system"
$ModelsDir = Join-Path $ProjectRoot "tts_models\piper"

# Piper模型URL
$Models = @(
    @{
        Name = "zh_CN-huayan-medium"
        OnnxUrl = "https://huggingface.co/rhasspy/piper-voices/resolve/main/zh_CN/zh_CN-huayan-medium/zh_CN-huayan-medium.onnx"
        JsonUrl = "https://huggingface.co/rhasspy/piper-voices/resolve/main/zh_CN/zh_CN-huayan-medium/zh_CN-huayan-medium.onnx.json"
        Size = "30 MB"
    }
)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  下载Piper TTS模型（性能引擎）" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 准备目录
# ============================================================
Write-Host "[1/3] 准备目录..." -ForegroundColor Yellow

if (-not (Test-Path $ModelsDir)) {
    New-Item -ItemType Directory -Path $ModelsDir -Force | Out-Null
}

Write-Host "  ✅ 目录准备完成" -ForegroundColor Green
Write-Host "  📁 模型目录: $ModelsDir" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 说明
# ============================================================
Write-Host "[2/3] 下载说明..." -ForegroundColor Yellow
Write-Host ""
Write-Host "  💡 Piper TTS是性能引擎，专为嵌入式设计" -ForegroundColor Cyan
Write-Host "  📦 模型大小: 10-50 MB" -ForegroundColor Cyan
Write-Host "  🌐 下载源: Hugging Face" -ForegroundColor Cyan
Write-Host "  ⏳ 预计时间: 5-10分钟" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 下载模型
# ============================================================
Write-Host "[3/3] 开始下载模型..." -ForegroundColor Yellow
Write-Host ""

$successCount = 0
$totalModels = $Models.Count

foreach ($model in $Models) {
    Write-Host "  📥 下载模型: $($model.Name)" -ForegroundColor Cyan
    Write-Host "     大小: $($model.Size)" -ForegroundColor Gray

    # 下载ONNX模型
    $onnxPath = Join-Path $ModelsDir "$($model.Name).onnx"
    Write-Host "     ⏳ 下载ONNX模型..." -ForegroundColor Gray

    try {
        # 使用curl下载（Windows 10+自带）
        & curl -L -o $onnxPath $model.OnnxUrl --progress-bar

        if ($LASTEXITCODE -eq 0) {
            $fileSize = (Get-Item $onnxPath).Length / 1MB
            Write-Host "     ✅ ONNX模型下载成功 ($([math]::Round($fileSize, 1)) MB)" -ForegroundColor Green
        } else {
            Write-Host "     ❌ ONNX模型下载失败" -ForegroundColor Red
            continue
        }
    } catch {
        Write-Host "     ❌ ONNX模型下载失败: $_" -ForegroundColor Red
        continue
    }

    # 下载JSON配置
    $jsonPath = Join-Path $ModelsDir "$($model.Name).onnx.json"
    Write-Host "     ⏳ 下载配置文件..." -ForegroundColor Gray

    try {
        & curl -L -o $jsonPath $model.JsonUrl --progress-bar

        if ($LASTEXITCODE -eq 0) {
            Write-Host "     ✅ 配置文件下载成功" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "     ❌ 配置文件下载失败" -ForegroundColor Red
        }
    } catch {
        Write-Host "     ❌ 配置文件下载失败: $_" -ForegroundColor Red
    }

    Write-Host ""
}

# ============================================================
# 统计结果
# ============================================================
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ 下载完成: $successCount/$totalModels 个模型" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

if (Test-Path $ModelsDir) {
    $totalSize = (Get-ChildItem $ModelsDir -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB

    Write-Host "📦 模型总大小: $([math]::Round($totalSize, 1)) MB" -ForegroundColor Cyan
    Write-Host "📁 模型位置: $ModelsDir" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "📋 模型列表:" -ForegroundColor Cyan
    Get-ChildItem $ModelsDir -File | ForEach-Object {
        $fileSize = $_.Length / 1MB
        Write-Host "   - $($_.Name): $([math]::Round($fileSize, 1)) MB" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "🚀 下一步: 测试Piper TTS语音合成" -ForegroundColor Yellow
Write-Host ""
