#Requires -Version 7.0
<#
.SYNOPSIS
    使用 Docker 在 Linux 环境下载 TTS 模型
.DESCRIPTION
    避免 Windows 上的 C++ 编译问题，使用 Docker 容器下载模型
.EXAMPLE
    .\03-download-tts-models-docker.ps1
.NOTES
    2026-02-13 19:00: 创建 - 使用 Docker 方案替代 Windows 直接下载
#>

$ErrorActionPreference = "Stop"

# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# ============================================================
# 配置
# ============================================================
$ProjectRoot = "E:\2025\3_gongkongji\belt_control_system"
$ModelsDir = Join-Path $ProjectRoot "libs\tts_models"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  TTS 模型下载工具（Docker 方案）" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📥 使用 Docker 在 Linux 环境下载 TTS 模型" -ForegroundColor Yellow
Write-Host "📂 目标目录: $ModelsDir" -ForegroundColor Yellow
Write-Host ""

# ============================================================
# Step 1: 检查 Docker
# ============================================================
Write-Host "[1/3] 检查 Docker 环境..." -ForegroundColor Yellow

$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Host "  ❌ 错误：未找到 Docker" -ForegroundColor Red
    Write-Host "  请先安装 Docker Desktop：https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
    exit 1
}

$dockerVersion = & docker --version 2>&1
Write-Host "  ✅ 找到 Docker: $dockerVersion" -ForegroundColor Green
Write-Host ""

# ============================================================
# Step 2: 确保目标目录存在
# ============================================================
Write-Host "[2/3] 准备目标目录..." -ForegroundColor Yellow

if (-not (Test-Path $ModelsDir)) {
    New-Item -ItemType Directory -Path $ModelsDir -Force | Out-Null
    Write-Host "  ✅ 创建模型目录: $ModelsDir" -ForegroundColor Green
} else {
    Write-Host "  ✅ 模型目录已存在" -ForegroundColor Green
}
Write-Host ""

# ============================================================
# Step 3: 使用 Docker 下载模型
# ============================================================
Write-Host "[3/3] 使用 Docker 下载 PaddleSpeech 模型..." -ForegroundColor Yellow
Write-Host "  ⏳ 这可能需要 10-20 分钟（取决于网络速度）" -ForegroundColor Yellow
Write-Host ""

$downloadScript = @"
set -e
echo '  📦 安装 paddlepaddle...'
pip install paddlepaddle -i https://pypi.tuna.tsinghua.edu.cn/simple --quiet

echo '  📦 安装 paddlespeech...'
pip install paddlespeech -i https://pypi.tuna.tsinghua.edu.cn/simple --quiet

echo '  📥 下载 PaddleSpeech 模型...'
python -c 'from paddlespeech.cli.tts import TTSExecutor; print(\"  初始化 TTS...\"); tts = TTSExecutor(); print(\"  ✅ 模型下载完成\")'

echo '  📂 复制模型到目标目录...'
cp -r ~/.paddlespeech /models/

echo '  ✅ 所有操作完成'
"@

try {
    & docker run --rm `
        -v "${ModelsDir}:/models" `
        python:3.11-slim `
        bash -c $downloadScript

    Write-Host ""
    Write-Host "  ✅ PaddleSpeech 模型下载成功" -ForegroundColor Green
} catch {
    Write-Host ""
    Write-Host "  ❌ Docker 下载失败: $_" -ForegroundColor Red
    Write-Host "  💡 可能原因：" -ForegroundColor Yellow
    Write-Host "     1. Docker 未运行" -ForegroundColor Yellow
    Write-Host "     2. 网络问题" -ForegroundColor Yellow
    Write-Host "     3. 磁盘空间不足" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# ============================================================
# 完成
# ============================================================
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ TTS 模型下载完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# 统计模型大小
if (Test-Path $ModelsDir) {
    $totalSize = (Get-ChildItem $ModelsDir -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "📊 模型总大小: $([math]::Round($totalSize, 1)) MB" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "📋 已下载的模型:" -ForegroundColor Cyan
    Get-ChildItem $ModelsDir -Directory | ForEach-Object {
        $modelSize = (Get-ChildItem $_.FullName -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
        Write-Host "   - $($_.Name): $([math]::Round($modelSize, 1)) MB" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "🚀 下一步: 同步模型到设备" -ForegroundColor Yellow
Write-Host "   .\scripts\2026-02-13\02-sync-tts-models.ps1 188" -ForegroundColor Gray
Write-Host ""
