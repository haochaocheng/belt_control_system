#Requires -Version 7.0
<#
.SYNOPSIS
    直接下载 VITS 模型文件（100%可靠方案）
.DESCRIPTION
    使用 Docker + wget 直接下载模型zip文件，绕过所有Python依赖问题
.EXAMPLE
    .\04-download-vits-model-direct.ps1
.NOTES
    2026-02-15 04:00: 创建 - 100%可靠的直接下载方案
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
Write-Host "  VITS 模型直接下载工具（100%可靠）" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📥 使用 Docker + wget 直接下载模型文件" -ForegroundColor Yellow
Write-Host "📂 目标目录: $ModelsDir" -ForegroundColor Yellow
Write-Host ""

# ============================================================
# Step 1: 检查 Docker
# ============================================================
Write-Host "[1/4] 检查 Docker 环境..." -ForegroundColor Yellow

$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
if (-not $dockerCmd) {
    Write-Host "  ❌ 错误：未找到 Docker" -ForegroundColor Red
    exit 1
}

$dockerVersion = & docker --version 2>&1
Write-Host "  ✅ 找到 Docker: $dockerVersion" -ForegroundColor Green
Write-Host ""

# ============================================================
# Step 2: 准备目标目录
# ============================================================
Write-Host "[2/4] 准备目标目录..." -ForegroundColor Yellow

if (-not (Test-Path $ModelsDir)) {
    New-Item -ItemType Directory -Path $ModelsDir -Force | Out-Null
    Write-Host "  ✅ 创建模型目录" -ForegroundColor Green
} else {
    Write-Host "  ✅ 模型目录已存在" -ForegroundColor Green
}

# 检查是否已下载
$vitsDir = Join-Path $ModelsDir "vits_csmsc_ckpt_1.4.0"
if (Test-Path $vitsDir) {
    $existingSize = (Get-ChildItem $vitsDir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
    if ($existingSize -gt 100) {
        Write-Host "  ⚠️  VITS 模型已存在 ($([math]::Round($existingSize, 1)) MB)" -ForegroundColor Yellow
        Write-Host "  是否重新下载？(Y/N)" -ForegroundColor Yellow
        $response = Read-Host
        if ($response -ne "Y" -and $response -ne "y") {
            Write-Host "  跳过下载" -ForegroundColor Gray
            exit 0
        }
        Remove-Item $vitsDir -Recurse -Force
        Write-Host "  ✅ 已删除旧模型" -ForegroundColor Green
    }
}

Write-Host ""

# ============================================================
# Step 3: 下载模型
# ============================================================
Write-Host "[3/4] 下载 VITS 模型..." -ForegroundColor Yellow
Write-Host "  📦 模型大小: 约 1.1 GB" -ForegroundColor Cyan
Write-Host "  ⏳ 预计时间: 5-10 分钟（取决于网络速度）" -ForegroundColor Cyan
Write-Host ""

$downloadScript = @"
set -e

echo '  📥 下载 VITS 模型...'
cd /models

# 下载模型zip文件
wget -q --show-progress \
    https://paddlespeech.bj.bcebos.com/Parakeet/released_models/vits/vits_csmsc_ckpt_1.4.0.zip \
    -O vits_csmsc.zip

echo ''
echo '  📂 解压模型文件...'
unzip -q vits_csmsc.zip

# 删除zip文件
rm vits_csmsc.zip

echo '  ✅ 模型下载完成'
"@

try {
    & docker run --rm `
        -v "${ModelsDir}:/models" `
        debian:bookworm-slim `
        bash -c "apt-get update -qq && apt-get install -y wget unzip -qq && $downloadScript"

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "  ❌ 下载失败（退出码: $LASTEXITCODE）" -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "  ✅ VITS 模型下载成功" -ForegroundColor Green
} catch {
    Write-Host ""
    Write-Host "  ❌ 下载失败: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ============================================================
# Step 4: 验证模型文件
# ============================================================
Write-Host "[4/4] 验证模型文件..." -ForegroundColor Yellow

$requiredFiles = @(
    "vits_csmsc_ckpt_1.4.0\default.yaml",
    "vits_csmsc_ckpt_1.4.0\snapshot_iter_150000.pdz",
    "vits_csmsc_ckpt_1.4.0\phone_id_map.txt"
)

$allFilesExist = $true
foreach ($file in $requiredFiles) {
    $filePath = Join-Path $ModelsDir $file
    if (Test-Path $filePath) {
        $fileSize = (Get-Item $filePath).Length / 1MB
        Write-Host "  ✅ $file ($([math]::Round($fileSize, 1)) MB)" -ForegroundColor Green
    } else {
        Write-Host "  ❌ 缺少文件: $file" -ForegroundColor Red
        $allFilesExist = $false
    }
}

if (-not $allFilesExist) {
    Write-Host ""
    Write-Host "  ❌ 模型文件不完整" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ============================================================
# 完成
# ============================================================
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ VITS 模型下载完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# 统计模型大小
$totalSize = (Get-ChildItem $vitsDir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host "📊 模型总大小: $([math]::Round($totalSize, 1)) MB" -ForegroundColor Cyan
Write-Host "📂 模型位置: $vitsDir" -ForegroundColor Cyan
Write-Host ""

Write-Host "🚀 下一步: 测试语音合成" -ForegroundColor Yellow
Write-Host "   .\scripts\2026-02-15\02-test-paddlespeech-vits.ps1" -ForegroundColor Gray
Write-Host ""
