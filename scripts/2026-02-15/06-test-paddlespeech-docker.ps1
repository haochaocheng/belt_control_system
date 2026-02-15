#Requires -Version 7.0
<#
.SYNOPSIS
    在Docker中测试PaddleSpeech VITS语音合成
.DESCRIPTION
    使用已下载的VITS模型在Docker环境中测试语音合成
.EXAMPLE
    .\06-test-paddlespeech-docker.ps1
.NOTES
    2026-02-15 04:40: 创建 - Docker测试方案
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
$OutputDir = Join-Path $ProjectRoot "test_output"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PaddleSpeech VITS 测试（Docker）" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Step 1: 检查模型
# ============================================================
Write-Host "[1/4] 检查模型文件..." -ForegroundColor Yellow

$vitsDir = Join-Path $ModelsDir "vits_csmsc_ckpt_1.4.0"
if (-not (Test-Path $vitsDir)) {
    Write-Host "  ❌ VITS模型不存在" -ForegroundColor Red
    Write-Host "  请先运行: .\scripts\2026-02-15\04-download-vits-model-direct.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host "  ✅ VITS模型存在" -ForegroundColor Green
Write-Host ""

# ============================================================
# Step 2: 准备输出目录
# ============================================================
Write-Host "[2/4] 准备输出目录..." -ForegroundColor Yellow

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

Write-Host "  ✅ 输出目录: $OutputDir" -ForegroundColor Green
Write-Host ""

# ============================================================
# Step 3: 创建测试脚本
# ============================================================
Write-Host "[3/4] 准备测试脚本..." -ForegroundColor Yellow

$testScript = @"
set -e

echo '  📦 安装编译工具...'
apt-get update -qq
apt-get install -y build-essential -qq

echo '  📦 安装Python依赖...'
pip install paddlepaddle==3.0.0 -i https://pypi.tuna.tsinghua.edu.cn/simple --quiet
pip install paddlespeech -i https://pypi.tuna.tsinghua.edu.cn/simple --quiet
pip install soundfile -i https://pypi.tuna.tsinghua.edu.cn/simple --quiet

echo '  🎤 测试语音合成...'
python3 << 'PYTHON_SCRIPT'
import sys
import os

# ✅ 2026-02-15 05:10 [修复]: 在导入paddlespeech前先修复aistudio_sdk
import aistudio_sdk.hub as hub
def download(*args, **kwargs):
    return None
hub.download = download
print('  ✅ aistudio_sdk补丁已应用')

# ✅ 2026-02-15 05:30 [修复]: 使用TTSExecutor而不是底层API
from paddlespeech.cli.tts import TTSExecutor

print('  📂 初始化TTS引擎...')
tts = TTSExecutor()

# 合成语音
text = '你好，欢迎使用飞桨语音合成系统'
output_path = '/output/test_output.wav'

print(f'  📝 合成文本: {text}')
print('  🎵 开始合成...')

# 使用默认模型合成
tts(
    text=text,
    output=output_path,
    am='fastspeech2_csmsc',
    voc='pwgan_csmsc',
    lang='zh'
)

print(f'  ✅ 音频已保存: {output_path}')

PYTHON_SCRIPT

echo '  ✅ 测试完成'
"@

Write-Host "  ✅ 测试脚本准备完成" -ForegroundColor Green
Write-Host ""

# ============================================================
# Step 4: 运行测试
# ============================================================
Write-Host "[4/4] 运行语音合成测试..." -ForegroundColor Yellow
Write-Host "  ⏳ 这可能需要 5-10 分钟（首次需要安装依赖）" -ForegroundColor Yellow
Write-Host ""

try {
    & docker run --rm `
        -v "${ModelsDir}:/models" `
        -v "${OutputDir}:/output" `
        python:3.11-slim `
        bash -c $testScript

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "  ❌ 测试失败（退出码: $LASTEXITCODE）" -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "  ✅ 语音合成测试成功" -ForegroundColor Green
} catch {
    Write-Host ""
    Write-Host "  ❌ 测试失败: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ============================================================
# 验证输出
# ============================================================
$outputFile = Join-Path $OutputDir "test_output.wav"
if (Test-Path $outputFile) {
    $fileSize = (Get-Item $outputFile).Length / 1KB
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "✅ 测试完成" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 输出文件: $outputFile" -ForegroundColor Cyan
    Write-Host "📊 文件大小: $([math]::Round($fileSize, 1)) KB" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "🎵 播放音频文件查看效果" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "❌ 输出文件未生成" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    exit 1
}
