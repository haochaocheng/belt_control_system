#Requires -Version 5.1
<#
.SYNOPSIS
    从 voices.json 下载 Piper TTS 中文模型
.DESCRIPTION
    解析 voices.json 文件，获取正确的下载路径
.EXAMPLE
    .\28-download-piper-from-voices-json.ps1
.NOTES
    2026-02-15 19:00: 创建 - 从 voices.json 下载 Piper TTS 模型
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
$VoicesJsonPath = Join-Path $ProjectRoot "temp\voices.json"
$BaseUrl = "https://huggingface.co/rhasspy/piper-voices/resolve/main"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  下载 Piper TTS 中文模型" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 读取 voices.json
# ============================================================
Write-Host "[1/3] 读取 voices.json..." -ForegroundColor Yellow

if (-not (Test-Path $VoicesJsonPath)) {
    Write-Host "  ❌ 未找到 voices.json，正在下载..." -ForegroundColor Red
    $tempDir = Join-Path $ProjectRoot "temp"
    if (-not (Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    }

    Invoke-WebRequest -Uri "https://huggingface.co/rhasspy/piper-voices/resolve/main/voices.json" `
        -OutFile $VoicesJsonPath -UseBasicParsing
}

$voicesJson = Get-Content $VoicesJsonPath -Raw | ConvertFrom-Json

Write-Host "  ✅ voices.json 读取成功" -ForegroundColor Green
Write-Host ""

# ============================================================
# 解析模型信息
# ============================================================
Write-Host "[2/3] 解析模型信息..." -ForegroundColor Yellow

$modelKey = "zh_CN-huayan-medium"
$model = $voicesJson.$modelKey

if (-not $model) {
    Write-Host "  ❌ 未找到模型: $modelKey" -ForegroundColor Red
    exit 1
}

Write-Host "  ✅ 找到模型: $modelKey" -ForegroundColor Green
Write-Host "  📝 模型名称: $($model.name)" -ForegroundColor Gray
Write-Host "  🌍 语言: $($model.language.name_native) ($($model.language.code))" -ForegroundColor Gray
Write-Host "  🎯 质量: $($model.quality)" -ForegroundColor Gray
Write-Host ""

# ============================================================
# 下载模型文件
# ============================================================
Write-Host "[3/3] 下载模型文件..." -ForegroundColor Yellow
Write-Host ""

if (-not (Test-Path $ModelsDir)) {
    New-Item -ItemType Directory -Path $ModelsDir -Force | Out-Null
}

$success = 0
$total = 0

foreach ($fileEntry in $model.files.PSObject.Properties) {
    $relativePath = $fileEntry.Name
    $fileInfo = $fileEntry.Value

    # 只下载 .onnx 和 .onnx.json 文件
    if ($relativePath -notmatch '\.(onnx|onnx\.json)$') {
        continue
    }

    $total++

    $fileName = Split-Path $relativePath -Leaf
    $localPath = Join-Path $ModelsDir $fileName
    $downloadUrl = "$BaseUrl/$relativePath"

    # 检查文件是否已存在且大小正确
    if (Test-Path $localPath) {
        $existingSize = (Get-Item $localPath).Length
        if ($existingSize -eq $fileInfo.size_bytes) {
            Write-Host "  ✅ 已存在: $fileName ($([math]::Round($existingSize / 1MB, 1)) MB)" -ForegroundColor Green
            $success++
            continue
        } else {
            Write-Host "  ⚠️  文件大小不匹配，重新下载: $fileName" -ForegroundColor Yellow
            Remove-Item $localPath -Force
        }
    }

    Write-Host "  📥 下载: $fileName ($([math]::Round($fileInfo.size_bytes / 1MB, 1)) MB)" -ForegroundColor Cyan

    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $localPath -UseBasicParsing

        $downloadedSize = (Get-Item $localPath).Length
        if ($downloadedSize -eq $fileInfo.size_bytes) {
            Write-Host "  ✅ 下载成功: $fileName" -ForegroundColor Green
            $success++
        } else {
            Write-Host "  ⚠️  文件大小不匹配: 预期 $($fileInfo.size_bytes) 字节，实际 $downloadedSize 字节" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ❌ 下载失败: $fileName" -ForegroundColor Red
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

Write-Host "📋 下载结果: $success/$total 个文件" -ForegroundColor Cyan
Write-Host ""

if ($success -eq $total) {
    Write-Host "🚀 下一步: 运行验证脚本" -ForegroundColor Yellow
    Write-Host "   .\scripts\2026-02-15\26-check-all-tts-models.ps1" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "⚠️  部分文件下载失败，请检查网络连接" -ForegroundColor Yellow
    Write-Host ""
}
