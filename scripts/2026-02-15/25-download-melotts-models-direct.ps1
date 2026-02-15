#Requires -Version 5.1
<#
.SYNOPSIS
    直接下载MeloTTS模型文件（无需Docker）
.DESCRIPTION
    从 Hugging Face 直接下载 MeloTTS 中文和英文模型
    避免安装依赖，只下载模型文件
.EXAMPLE
    .\25-download-melotts-models-direct.ps1
.NOTES
    2026-02-15 18:00: 创建 - 直接下载 MeloTTS 模型文件
#>

$ErrorActionPreference = "Stop"

# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# ============================================================
# 配置
# ============================================================
$ProjectRoot = "E:\2025\3_gongkongji\belt_control_system"
$ModelsDir = Join-Path $ProjectRoot "tts_models\melotts"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  下载MeloTTS模型（直接下载）" -ForegroundColor Cyan
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
Write-Host "  📁 模型目录: $ModelsDir" -ForegroundColor Gray
Write-Host ""

# ============================================================
# 下载中文模型
# ============================================================
Write-Host "[2/3] 下载中文模型..." -ForegroundColor Yellow
Write-Host ""

$zhModelDir = Join-Path $ModelsDir "MeloTTS-Chinese"
if (-not (Test-Path $zhModelDir)) {
    New-Item -ItemType Directory -Path $zhModelDir -Force | Out-Null
}

$zhFiles = @(
    @{
        Name = "checkpoint.pth"
        Url = "https://huggingface.co/myshell-ai/MeloTTS-Chinese/resolve/main/checkpoint.pth?download=true"
        Size = "208 MB"
    },
    @{
        Name = "config.json"
        Url = "https://huggingface.co/myshell-ai/MeloTTS-Chinese/resolve/main/config.json?download=true"
        Size = "2.3 KB"
    }
)

$zhSuccess = 0
foreach ($file in $zhFiles) {
    $filePath = Join-Path $zhModelDir $file.Name

    if (Test-Path $filePath) {
        Write-Host "  ✅ 已存在: $($file.Name)" -ForegroundColor Green
        $zhSuccess++
        continue
    }

    Write-Host "  📥 下载: $($file.Name) ($($file.Size))" -ForegroundColor Cyan

    try {
        Invoke-WebRequest -Uri $file.Url -OutFile $filePath -UseBasicParsing
        Write-Host "  ✅ 下载成功: $($file.Name)" -ForegroundColor Green
        $zhSuccess++
    } catch {
        Write-Host "  ❌ 下载失败: $($file.Name)" -ForegroundColor Red
        Write-Host "     错误: $_" -ForegroundColor Red
    }

    Write-Host ""
}

Write-Host "  📊 中文模型: $zhSuccess/$($zhFiles.Count) 个文件" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 下载英文模型
# ============================================================
Write-Host "[3/3] 下载英文模型..." -ForegroundColor Yellow
Write-Host ""

$enModelDir = Join-Path $ModelsDir "MeloTTS-English"
if (-not (Test-Path $enModelDir)) {
    New-Item -ItemType Directory -Path $enModelDir -Force | Out-Null
}

$enFiles = @(
    @{
        Name = "checkpoint.pth"
        Url = "https://huggingface.co/myshell-ai/MeloTTS-English/resolve/main/checkpoint.pth?download=true"
        Size = "208 MB"
    },
    @{
        Name = "config.json"
        Url = "https://huggingface.co/myshell-ai/MeloTTS-English/resolve/main/config.json?download=true"
        Size = "2.3 KB"
    }
)

$enSuccess = 0
foreach ($file in $enFiles) {
    $filePath = Join-Path $enModelDir $file.Name

    if (Test-Path $filePath) {
        Write-Host "  ✅ 已存在: $($file.Name)" -ForegroundColor Green
        $enSuccess++
        continue
    }

    Write-Host "  📥 下载: $($file.Name) ($($file.Size))" -ForegroundColor Cyan

    try {
        Invoke-WebRequest -Uri $file.Url -OutFile $filePath -UseBasicParsing
        Write-Host "  ✅ 下载成功: $($file.Name)" -ForegroundColor Green
        $enSuccess++
    } catch {
        Write-Host "  ❌ 下载失败: $($file.Name)" -ForegroundColor Red
        Write-Host "     错误: $_" -ForegroundColor Red
    }

    Write-Host ""
}

Write-Host "  📊 英文模型: $enSuccess/$($enFiles.Count) 个文件" -ForegroundColor Cyan
Write-Host ""

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

Write-Host "📋 模型列表:" -ForegroundColor Cyan
Write-Host "  - MeloTTS-Chinese: $zhSuccess/$($zhFiles.Count) 个文件" -ForegroundColor Gray
Write-Host "  - MeloTTS-English: $enSuccess/$($enFiles.Count) 个文件" -ForegroundColor Gray
Write-Host ""

Write-Host "🚀 下一步: 复制模型到 RK3588" -ForegroundColor Yellow
Write-Host "   scp -r $ModelsDir linaro@192.168.10.188:/app/models/" -ForegroundColor Gray
Write-Host ""
