#Requires -Version 5.1
<#
.SYNOPSIS
    导出PaddleSpeech模型到本地目录
.DESCRIPTION
    重新运行下载，但将模型缓存目录挂载到本地，以便离线使用
.EXAMPLE
    .\12-export-paddlespeech-models.ps1
.NOTES
    2026-02-15 14:05: 创建 - 导出模型供离线使用
#>

$ErrorActionPreference = "Stop"

# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# ============================================================
# 配置
# ============================================================
$ProjectRoot = "E:\2025\3_gongkongji\belt_control_system"
$ModelsDir = Join-Path $ProjectRoot "tts_models\paddlespeech_offline"
$OutputDir = Join-Path $ProjectRoot "test_output"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  导出PaddleSpeech模型（离线使用）" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 准备目录
# ============================================================
Write-Host "[1/3] 准备目录..." -ForegroundColor Yellow

if (-not (Test-Path $ModelsDir)) {
    New-Item -ItemType Directory -Path $ModelsDir -Force | Out-Null
}

if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

Write-Host "  ✅ 目录准备完成" -ForegroundColor Green
Write-Host "  📁 模型目录: $ModelsDir" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 说明
# ============================================================
Write-Host "[2/3] 下载说明..." -ForegroundColor Yellow
Write-Host ""
Write-Host "  💡 本次下载会将模型保存到本地目录，供离线使用" -ForegroundColor Cyan
Write-Host "  📦 模型将保存到: $ModelsDir" -ForegroundColor Cyan
Write-Host "  ⏳ 预计时间: 5-10分钟（模型已缓存，只需复制）" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 创建Python下载脚本
# ============================================================
Write-Host "[3/3] 开始导出模型..." -ForegroundColor Yellow
Write-Host ""

$pythonScript = @"
import sys
import os
import json

# ✅ 应用aistudio_sdk补丁
import aistudio_sdk.hub as hub
def download(*args, **kwargs):
    return None
hub.download = download

from paddlespeech.cli.tts import TTSExecutor

# 初始化TTS
print('  📂 初始化TTS引擎...')
tts = TTSExecutor()

# 只下载已验证成功的8个模型
models = [
    {"Name": "FastSpeech2-CSMSC", "AM": "fastspeech2_csmsc", "VOC": "pwgan_csmsc", "Lang": "zh", "Text": "测试"},
    {"Name": "FastSpeech2-AISHELL3", "AM": "fastspeech2_aishell3", "VOC": "pwgan_aishell3", "Lang": "zh", "Text": "测试", "SpkId": 0},
    {"Name": "VITS-CSMSC", "AM": "vits_csmsc", "Lang": "zh", "Text": "测试"},
    {"Name": "VITS-AISHELL3", "AM": "vits_aishell3", "Lang": "zh", "Text": "测试", "SpkId": 0},
    {"Name": "FastSpeech2-Mix", "AM": "fastspeech2_mix", "VOC": "pwgan_csmsc", "Lang": "mix", "Text": "Hello"},
    {"Name": "FastSpeech2-LJSpeech", "AM": "fastspeech2_ljspeech", "VOC": "pwgan_ljspeech", "Lang": "en", "Text": "Hello"},
    {"Name": "FastSpeech2-VCTK", "AM": "fastspeech2_vctk", "VOC": "pwgan_vctk", "Lang": "en", "Text": "Hello", "SpkId": 0},
    {"Name": "FastSpeech2-Canton", "AM": "fastspeech2_canton", "VOC": "pwgan_canton", "Lang": "canton", "Text": "你好"}
]

success_count = 0
for i, model in enumerate(models, 1):
    name = model['Name']
    print(f'\n  [{i}/8] {name}')

    try:
        params = {
            'text': model['Text'],
            'output': f'/output/{model["AM"]}_test.wav',
            'am': model['AM'],
            'lang': model['Lang']
        }

        if 'VOC' in model:
            params['voc'] = model['VOC']

        if 'SpkId' in model:
            params['spk_id'] = model['SpkId']

        print(f'     ⏳ 下载模型...')
        tts(**params)
        print(f'     ✅ 成功')
        success_count += 1

    except Exception as e:
        print(f'     ❌ 失败: {str(e)}')

print(f'\n========================================')
print(f'✅ 导出完成: {success_count}/8 个模型')
print(f'========================================\n')
print(f'📁 模型已保存到: /models')
"@

# 保存Python脚本
$pythonScriptPath = Join-Path $OutputDir "export_models.py"
$pythonScript | Out-File -FilePath $pythonScriptPath -Encoding utf8

# ============================================================
# 运行Docker容器（挂载模型目录）
# ============================================================
Write-Host "  🐳 启动Docker容器..." -ForegroundColor Cyan
Write-Host ""

try {
    & docker run --rm `
        -v "${ModelsDir}:/models" `
        -v "${OutputDir}:/output" `
        -e "PADDLESPEECH_HOME=/models" `
        python:3.11-slim `
        bash -c @"
set -e

echo '  📦 安装编译工具...'
apt-get update -qq
apt-get install -y build-essential -qq

echo '  📦 安装Python依赖...'
pip install paddlepaddle==3.0.0 -i https://pypi.tuna.tsinghua.edu.cn/simple --quiet
pip install paddlespeech -i https://pypi.tuna.tsinghua.edu.cn/simple --quiet
pip install soundfile -i https://pypi.tuna.tsinghua.edu.cn/simple --quiet

echo '  🚀 开始导出模型...'
python3 /output/export_models.py

echo ''
echo '  📦 复制模型到挂载目录...'
if [ -d /root/.paddlespeech ]; then
    cp -r /root/.paddlespeech/* /models/ 2>/dev/null || echo '  ⚠️  复制失败'
    echo '  ✅ 模型已复制'
else
    echo '  ⚠️  未找到模型缓存'
fi

echo ''
echo '  📊 模型目录大小:'
du -sh /models/* 2>/dev/null || echo '  (空)'
"@

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "  ❌ 导出失败（退出码: $LASTEXITCODE）" -ForegroundColor Red
        exit 1
    }

} catch {
    Write-Host ""
    Write-Host "  ❌ 错误: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ============================================================
# 统计模型大小
# ============================================================
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ 导出完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

if (Test-Path $ModelsDir) {
    $totalSize = (Get-ChildItem $ModelsDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB

    Write-Host "📦 模型总大小: $([math]::Round($totalSize, 2)) GB" -ForegroundColor Cyan
    Write-Host "📁 模型位置: $ModelsDir" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "📋 模型列表:" -ForegroundColor Cyan
    Get-ChildItem $ModelsDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $modelSize = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
        if ($modelSize -gt 0) {
            Write-Host "   - $($_.Name): $([math]::Round($modelSize, 1)) MB" -ForegroundColor Gray
        }
    }

    Write-Host ""
    Write-Host "🚀 下一步: 同步模型到RK3588设备" -ForegroundColor Yellow
    Write-Host "   scp -r $ModelsDir linaro@192.168.10.188:/app/models/" -ForegroundColor Gray
}

Write-Host ""
