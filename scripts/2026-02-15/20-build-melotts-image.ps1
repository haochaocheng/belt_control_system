#Requires -Version 5.1
<#
.SYNOPSIS
    构建MeloTTS Docker镜像（缓存方案）
.DESCRIPTION
    构建包含MeloTTS和所有依赖的Docker镜像
    一次构建，多次使用，避免重复安装
.EXAMPLE
    .\20-build-melotts-image.ps1
.NOTES
    2026-02-15 16:40: 创建 - 构建MeloTTS缓存镜像
#>

$ErrorActionPreference = "Stop"

# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# ============================================================
# 配置
# ============================================================
$ProjectRoot = "E:\2025\3_gongkongji\belt_control_system"
$TempDir = Join-Path $ProjectRoot "temp\melotts"
$ImageName = "melotts-downloader:latest"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  构建MeloTTS Docker镜像" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 准备目录
# ============================================================
Write-Host "[1/3] 准备目录..." -ForegroundColor Yellow

if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
}

Write-Host "  ✅ 目录准备完成" -ForegroundColor Green
Write-Host ""

# ============================================================
# 检查镜像是否已存在
# ============================================================
Write-Host "[2/3] 检查Docker镜像..." -ForegroundColor Yellow

$imageExists = docker images -q $ImageName 2>$null

if ($imageExists) {
    Write-Host "  ✅ 镜像已存在: $ImageName" -ForegroundColor Green
    Write-Host "  💡 如需重新构建，请先删除镜像: docker rmi $ImageName" -ForegroundColor Cyan
    Write-Host ""
    exit 0
}

Write-Host "  ⚠️  未找到镜像，开始构建..." -ForegroundColor Yellow
Write-Host ""

# ============================================================
# 创建Dockerfile
# ============================================================
Write-Host "[3/3] 构建Docker镜像..." -ForegroundColor Yellow
Write-Host ""

$dockerfile = @"
FROM python:3.11-slim

# 安装系统依赖
RUN apt-get update -qq && \
    apt-get install -y git build-essential -qq && \
    rm -rf /var/lib/apt/lists/*

# 安装PyTorch（CPU版本）
RUN pip install --no-cache-dir \
    torch==2.1.0 \
    torchaudio==2.1.0 \
    --index-url https://download.pytorch.org/whl/cpu

# 安装其他Python依赖
RUN pip install --no-cache-dir \
    numpy \
    scipy \
    librosa \
    soundfile

# 安装MeloTTS
RUN pip install --no-cache-dir \
    git+https://github.com/myshell-ai/MeloTTS.git

# 设置工作目录
WORKDIR /app

CMD ["/bin/bash"]
"@

$dockerfilePath = Join-Path $TempDir "Dockerfile"
$dockerfile | Out-File -FilePath $dockerfilePath -Encoding utf8 -NoNewline

Write-Host "  📝 Dockerfile已创建: $dockerfilePath" -ForegroundColor Gray
Write-Host ""
Write-Host "  🐳 开始构建镜像（这可能需要10-15分钟）..." -ForegroundColor Cyan
Write-Host "  💡 主要时间用于下载PyTorch（约500 MB）" -ForegroundColor Gray
Write-Host ""

try {
    & docker build -t $ImageName -f $dockerfilePath $TempDir

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "  ❌ Docker镜像构建失败" -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "  ✅ Docker镜像构建成功" -ForegroundColor Green

} catch {
    Write-Host ""
    Write-Host "  ❌ 错误: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ============================================================
# 统计镜像信息
# ============================================================
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ 镜像构建完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# 查看镜像信息
$imageInfo = docker images $ImageName --format "{{.Size}}"
Write-Host "📦 镜像名称: $ImageName" -ForegroundColor Cyan
Write-Host "📦 镜像大小: $imageInfo" -ForegroundColor Cyan
Write-Host ""

Write-Host "🚀 下一步: 使用镜像下载MeloTTS模型" -ForegroundColor Yellow
Write-Host "   .\scripts\2026-02-15\21-download-melotts-with-cache.ps1" -ForegroundColor Gray
Write-Host ""

Write-Host "💡 提示: 镜像已缓存，后续下载模型只需2-3分钟" -ForegroundColor Cyan
Write-Host ""
