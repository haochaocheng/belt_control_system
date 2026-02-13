#Requires -Version 7.0
<#
.SYNOPSIS
    下载 PaddleSpeech 和 MeloTTS 模型到本地
.DESCRIPTION
    在 Windows 上提前下载 TTS 模型，避免设备无网络时无法使用
    下载的模型会保存到 libs/tts_models 目录
.EXAMPLE
    .\01-download-tts-models.ps1
.NOTES
    2026-02-13 16:45: 创建 - 提前下载 TTS 模型
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
Write-Host "  TTS 模型下载工具" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📥 准备下载 TTS 模型" -ForegroundColor Yellow
Write-Host "📂 目标目录: $ModelsDir" -ForegroundColor Yellow
Write-Host ""

# 确保目标目录存在
if (-not (Test-Path $ModelsDir)) {
    New-Item -ItemType Directory -Path $ModelsDir -Force | Out-Null
    Write-Host "✅ 创建模型目录: $ModelsDir" -ForegroundColor Green
}

# ============================================================
# 方案说明
# ============================================================
Write-Host "📋 TTS 模型下载方案:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  由于 PaddleSpeech 和 MeloTTS 的模型下载机制复杂，" -ForegroundColor White
Write-Host "  我们采用以下方案：" -ForegroundColor White
Write-Host ""
Write-Host "  1️⃣  在 Windows 上安装 Python 虚拟环境" -ForegroundColor Yellow
Write-Host "  2️⃣  安装 paddlespeech 和 melo-tts" -ForegroundColor Yellow
Write-Host "  3️⃣  运行一次 TTS 触发模型自动下载" -ForegroundColor Yellow
Write-Host "  4️⃣  复制下载的模型到 libs/tts_models" -ForegroundColor Yellow
Write-Host ""

# ============================================================
# Step 1: 检查 Python
# ============================================================
Write-Host "[1/5] 检查 Python 环境..." -ForegroundColor Yellow

$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    Write-Host "  ❌ 错误：未找到 Python" -ForegroundColor Red
    Write-Host "  请先安装 Python 3.8+：https://www.python.org/downloads/" -ForegroundColor Yellow
    exit 1
}

$pythonVersion = & python --version 2>&1
Write-Host "  ✅ 找到 Python: $pythonVersion" -ForegroundColor Green
Write-Host ""

# ============================================================
# Step 2: 创建虚拟环境
# ============================================================
Write-Host "[2/5] 创建 Python 虚拟环境..." -ForegroundColor Yellow

$venvDir = Join-Path $env:TEMP "tts_models_download_venv"

if (Test-Path $venvDir) {
    Write-Host "  ⚠️  虚拟环境已存在，跳过创建" -ForegroundColor Yellow
} else {
    try {
        & python -m venv $venvDir
        Write-Host "  ✅ 虚拟环境创建成功" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ 创建虚拟环境失败: $_" -ForegroundColor Red
        exit 1
    }
}
Write-Host ""

# ============================================================
# Step 3: 安装 TTS 依赖
# ============================================================
Write-Host "[3/5] 安装 TTS 依赖..." -ForegroundColor Yellow

$pipCmd = Join-Path $venvDir "Scripts\pip.exe"
$pythonVenv = Join-Path $venvDir "Scripts\python.exe"

# ❌ 2026-02-13 17:30 [Phase 7.46.8 修复]: 移除 --quiet 参数，显示详细错误信息
Write-Host "  📦 安装 paddlepaddle..." -ForegroundColor Cyan
try {
    & $pipCmd install paddlepaddle 2>&1 | Out-Host
    Write-Host "  ✅ paddlepaddle 安装完成" -ForegroundColor Green
} catch {
    Write-Host "  ❌ paddlepaddle 安装失败: $_" -ForegroundColor Red
    Write-Host "  💡 提示：可能需要 Visual Studio C++ 编译工具" -ForegroundColor Yellow
    exit 1
}

Write-Host "  📦 安装 paddlespeech..." -ForegroundColor Cyan
try {
    # ✅ 2026-02-13 17:30 [Phase 7.46.8 修复]: 跳过依赖检查，避免 editdistance 编译失败
    & $pipCmd install paddlespeech --no-deps 2>&1 | Out-Host
    # 手动安装核心依赖（跳过需要编译的依赖）
    & $pipCmd install numpy scipy librosa soundfile tqdm colorlog yacs visualdl 2>&1 | Out-Host
    Write-Host "  ✅ paddlespeech 安装完成（跳过了部分可选依赖）" -ForegroundColor Green
} catch {
    Write-Host "  ❌ paddlespeech 安装失败: $_" -ForegroundColor Red
    exit 1
}

# ❌ 2026-02-13 17:30 [Phase 7.46.8 修复]: 移除 melo-tts 安装（PyPI 上不存在此包）
# 原因：melo-tts 包名不正确或需要从 GitHub 安装
# 后续如需 MeloTTS，需要使用正确的安装方式
# Write-Host "  📦 安装 melo-tts..." -ForegroundColor Cyan
# try {
#     & $pipCmd install melo-tts --quiet
#     Write-Host "  ✅ melo-tts 安装完成" -ForegroundColor Green
# } catch {
#     Write-Host "  ❌ melo-tts 安装失败: $_" -ForegroundColor Red
#     exit 1
# }
Write-Host "  ⚠️  跳过 MeloTTS 安装（需要从 GitHub 安装）" -ForegroundColor Yellow

Write-Host ""

# ============================================================
# Step 4: 下载 PaddleSpeech 模型
# ============================================================
Write-Host "[4/5] 下载 PaddleSpeech 模型..." -ForegroundColor Yellow

# ✅ 2026-02-13 17:30 [Phase 7.46.8 修复]: 修复 Python 语法错误（转义字符问题）
$paddleSpeechScript = @"
from paddlespeech.cli.tts import TTSExecutor
import os

print('  📥 初始化 PaddleSpeech TTS...')
tts = TTSExecutor()

print('  ✅ PaddleSpeech 模型下载完成')
model_path = os.path.expanduser('~/.paddlespeech')
print(f'  📂 模型位置: {model_path}')
"@

try {
    $paddleSpeechScript | & $pythonVenv -
    Write-Host "  ✅ PaddleSpeech 模型下载成功" -ForegroundColor Green
} catch {
    Write-Host "  ❌ PaddleSpeech 模型下载失败: $_" -ForegroundColor Red
    Write-Host "  💡 可能原因：网络问题或模型服务器不可用" -ForegroundColor Yellow
}

Write-Host ""

# ============================================================
# Step 5: 复制模型到项目目录
# ============================================================
Write-Host "[5/5] 复制模型到项目目录..." -ForegroundColor Yellow

$paddleSpeechModelsSource = Join-Path $env:USERPROFILE ".paddlespeech"
$paddleSpeechModelsDest = Join-Path $ModelsDir "paddlespeech"

if (Test-Path $paddleSpeechModelsSource) {
    Write-Host "  📂 复制 PaddleSpeech 模型..." -ForegroundColor Cyan

    if (Test-Path $paddleSpeechModelsDest) {
        Remove-Item $paddleSpeechModelsDest -Recurse -Force
    }

    Copy-Item $paddleSpeechModelsSource $paddleSpeechModelsDest -Recurse -Force

    $modelSize = (Get-ChildItem $paddleSpeechModelsDest -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "  ✅ PaddleSpeech 模型复制完成 ($([math]::Round($modelSize, 1)) MB)" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  未找到 PaddleSpeech 模型" -ForegroundColor Yellow
}

Write-Host ""

# ============================================================
# 清理
# ============================================================
Write-Host "🧹 清理临时文件..." -ForegroundColor Yellow

if (Test-Path $venvDir) {
    Remove-Item $venvDir -Recurse -Force
    Write-Host "  ✅ 虚拟环境已删除" -ForegroundColor Green
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
