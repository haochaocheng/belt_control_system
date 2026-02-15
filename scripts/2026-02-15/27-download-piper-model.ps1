#Requires -Version 5.1
<#
.SYNOPSIS
    下载 Piper TTS 中文模型
.DESCRIPTION
    从 Hugging Face 下载 Piper TTS 的中文 ONNX 模型
.EXAMPLE
    .\27-download-piper-model.ps1
.NOTES
    2026-02-15 18:50: 创建 - 下载 Piper TTS 中文模型
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

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  下载 Piper TTS 中文模型" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 准备目录
# ============================================================
Write-Host "[1/2] 准备目录..." -ForegroundColor Yellow

if (-not (Test-Path $ModelsDir)) {
    New-Item -ItemType Directory -Path $ModelsDir -Force | Out-Null
}

Write-Host "  ✅ 目录准备完成" -ForegroundColor Green
Write-Host "  📁 模型目录: $ModelsDir" -ForegroundColor Gray
Write-Host ""

# ============================================================
# 下载模型文件
# ============================================================
Write-Host "[2/2] 下载模型文件..." -ForegroundColor Yellow
Write-Host ""

# Piper TTS 中文模型
$modelFiles = @(
    @{
        Name = "zh_CN-huayan-medium.onnx"
        Url = "https://huggingface.co/rhasspy/piper-voices/resolve/main/zh_CN/zh_CN-huayan-medium/zh_CN-huayan-medium.onnx?download=true"
        Size = "~30 MB"
    },
    @{
        Name = "zh_CN-huayan-medium.onnx.json"
        Url = "https://huggingface.co/rhasspy/piper-voices/resolve/main/zh_CN/zh_CN-huayan-medium/zh_CN-huayan-medium.onnx.json?download=true"
        Size = "~1 KB"
    }
)

$success = 0
foreach ($file in $modelFiles) {
    $filePath = Join-Path $ModelsDir $file.Name

    # 如果文件已存在且大小正常，跳过
    if (Test-Path $filePath) {
        $fileSize = (Get-Item $filePath).Length
        if ($fileSize -gt 1000) {  # 大于 1KB 认为是有效文件
            Write-Host "  ✅ 已存在: $($file.Name) ($([math]::Round($fileSize / 1MB, 1)) MB)" -ForegroundColor Green
            $success++
            continue
        } else {
            Write-Host "  ⚠️  文件损坏，重新下载: $($file.Name)" -ForegroundColor Yellow
            Remove-Item $filePath -Force
        }
    }

    Write-Host "  📥 下载: $($file.Name) ($($file.Size))" -ForegroundColor Cyan

    try {
        Invoke-WebRequest -Uri $file.Url -OutFile $filePath -UseBasicParsing

        $downloadedSize = (Get-Item $filePath).Length
        Write-Host "  ✅ 下载成功: $($file.Name) ($([math]::Round($downloadedSize / 1MB, 1)) MB)" -ForegroundColor Green
        $success++
    } catch {
        Write-Host "  ❌ 下载失败: $($file.Name)" -ForegroundColor Red
        Write-Host "     错误: $_" -ForegroundColor Red
    }

    Write-Host ""
}

# ============================================================
# 统计总结
# ============================================================
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ 下载完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

$totalSize = 0
if (Test-Path $ModelsDir) {
    $totalSize = (Get-ChildItem $ModelsDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
}

Write-Host "📦 模型总大小: $([math]::Round($totalSize, 1)) MB" -ForegroundColor Cyan
Write-Host "📁 模型位置: $ModelsDir" -ForegroundColor Cyan
Write-Host ""

Write-Host "📋 下载结果: $success/$($modelFiles.Count) 个文件" -ForegroundColor Cyan
Write-Host ""

if ($success -eq $modelFiles.Count) {
    Write-Host "🚀 下一步: 运行验证脚本" -ForegroundColor Yellow
    Write-Host "   .\scripts\2026-02-15\26-check-all-tts-models.ps1" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "⚠️  部分文件下载失败，请检查网络连接" -ForegroundColor Yellow
    Write-Host ""
}
