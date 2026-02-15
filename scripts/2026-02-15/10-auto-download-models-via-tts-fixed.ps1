# ✅ 2026-02-15 13:05 [修复]: 兼容PowerShell 5.1
#Requires -Version 5.1
<#
.SYNOPSIS
    使用PaddleSpeech TTSExecutor自动下载模型（修复版）
.DESCRIPTION
    通过调用TTSExecutor，让PaddleSpeech自动下载最新版本的模型
    ✅ 2026-02-15 13:00 [修复]: 移除VITS模型的VOC字段，避免null转换问题
.EXAMPLE
    .\10-auto-download-models-via-tts-fixed.ps1
.NOTES
    2026-02-15 13:00: 修复 - 解决null转换问题
#>

$ErrorActionPreference = "Stop"

# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# ============================================================
# 配置
# ============================================================
$ProjectRoot = "E:\2025\3_gongkongji\belt_control_system"
$ModelsDir = Join-Path $ProjectRoot "tts_models\paddlespeech"
$OutputDir = Join-Path $ProjectRoot "test_output"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PaddleSpeech 自动下载模型（修复版）" -ForegroundColor Cyan
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
Write-Host ""

# ============================================================
# 模型列表（手动构建JSON字符串，避免null问题）
# ============================================================
Write-Host "[2/3] 准备模型列表..." -ForegroundColor Yellow
Write-Host ""

# ✅ 2026-02-15 13:00 [修复]: 手动构建JSON，VITS模型不包含voc字段
$modelsJson = @'
[
  {
    "Name": "FastSpeech2-CSMSC (中文女声)",
    "AM": "fastspeech2_csmsc",
    "VOC": "pwgan_csmsc",
    "Lang": "zh",
    "Text": "你好，这是中文女声测试",
    "Priority": 1
  },
  {
    "Name": "FastSpeech2-AISHELL3 (中文多说话人)",
    "AM": "fastspeech2_aishell3",
    "VOC": "pwgan_aishell3",
    "Lang": "zh",
    "Text": "你好，这是中文多说话人测试",
    "SpkId": 0,
    "Priority": 1
  },
  {
    "Name": "VITS-CSMSC (中文女声，高质量)",
    "AM": "vits_csmsc",
    "Lang": "zh",
    "Text": "你好，这是高质量中文女声测试",
    "Priority": 2
  },
  {
    "Name": "VITS-AISHELL3 (中文多说话人，高质量)",
    "AM": "vits_aishell3",
    "Lang": "zh",
    "Text": "你好，这是高质量多说话人测试",
    "SpkId": 0,
    "Priority": 2
  },
  {
    "Name": "FastSpeech2-Mix (中英混合)",
    "AM": "fastspeech2_mix",
    "VOC": "pwgan_csmsc",
    "Lang": "mix",
    "Text": "Hello, 这是中英混合测试",
    "Priority": 3
  },
  {
    "Name": "FastSpeech2-LJSpeech (英文女声)",
    "AM": "fastspeech2_ljspeech",
    "VOC": "pwgan_ljspeech",
    "Lang": "en",
    "Text": "Hello, this is English female voice test",
    "Priority": 3
  },
  {
    "Name": "FastSpeech2-VCTK (英文多说话人)",
    "AM": "fastspeech2_vctk",
    "VOC": "pwgan_vctk",
    "Lang": "en",
    "Text": "Hello, this is English multi-speaker test",
    "SpkId": 0,
    "Priority": 3
  },
  {
    "Name": "FastSpeech2-Canton (粤语)",
    "AM": "fastspeech2_canton",
    "VOC": "pwgan_canton",
    "Lang": "canton",
    "Text": "你好，呢個係粵語測試",
    "Priority": 4
  },
  {
    "Name": "SpeedySpeech-CSMSC (中文快速)",
    "AM": "speedyspeech_csmsc",
    "VOC": "pwgan_csmsc",
    "Lang": "zh",
    "Text": "你好，这是快速语音合成测试",
    "Priority": 4
  }
]
'@

Write-Host "  📋 计划下载 9 个模型组合" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 创建Python下载脚本
# ============================================================
Write-Host "[3/3] 开始自动下载..." -ForegroundColor Yellow
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

# 模型列表
models = $modelsJson

results = {
    'success': [],
    'failed': []
}

for model in models:
    name = model['Name']
    am = model['AM']
    voc = model.get('VOC')  # VITS模型没有这个字段
    lang = model['Lang']
    text = model['Text']
    spk_id = model.get('SpkId', 0)

    print(f'\n  📥 {name}')
    print(f'     AM: {am}')
    if voc:
        print(f'     VOC: {voc}')
    else:
        print(f'     VOC: 无需（端到端模型）')

    try:
        # 构建参数
        params = {
            'text': text,
            'output': f'/output/{am}_test.wav',
            'am': am,
            'lang': lang
        }

        # 只有非VITS模型才需要声码器
        if voc:
            params['voc'] = voc

        # 多说话人模型需要spk_id
        if 'SpkId' in model:
            params['spk_id'] = spk_id

        # 调用TTS（会自动下载模型）
        print(f'     ⏳ 下载并测试中...')
        tts(**params)

        print(f'     ✅ 成功')
        results['success'].append(name)

    except Exception as e:
        print(f'     ❌ 失败: {str(e)}')
        results['failed'].append({'name': name, 'error': str(e)})

# 输出结果
print('\n========================================')
print('✅ 下载完成')
print('========================================\n')

print(f'📊 下载统计:')
print(f'  ✅ 成功: {len(results["success"])} 个模型')
print(f'  ❌ 失败: {len(results["failed"])} 个模型')

if results['success']:
    print('\n  成功的模型:')
    for name in results['success']:
        print(f'    - {name}')

if results['failed']:
    print('\n  失败的模型:')
    for item in results['failed']:
        print(f'    - {item["name"]}')
        print(f'      错误: {item["error"]}')

# 保存结果
with open('/output/download_results.json', 'w', encoding='utf-8') as f:
    json.dump(results, f, ensure_ascii=False, indent=2)

print('\n📝 详细结果已保存到: download_results.json')
"@

# 保存Python脚本
$pythonScriptPath = Join-Path $OutputDir "download_models.py"
$pythonScript | Out-File -FilePath $pythonScriptPath -Encoding utf8

# ============================================================
# 运行Docker容器
# ============================================================
Write-Host "  🐳 启动Docker容器..." -ForegroundColor Cyan
Write-Host ""

$dockerScript = @"
set -e

echo '  📦 安装编译工具...'
apt-get update -qq
apt-get install -y build-essential -qq

echo '  📦 安装Python依赖...'
pip install paddlepaddle==3.0.0 -i https://pypi.tuna.tsinghua.edu.cn/simple --quiet
pip install paddlespeech -i https://pypi.tuna.tsinghua.edu.cn/simple --quiet
pip install soundfile -i https://pypi.tuna.tsinghua.edu.cn/simple --quiet

echo '  🚀 开始自动下载模型...'
python3 /output/download_models.py

echo '  ✅ 所有操作完成'
"@

try {
    & docker run --rm `
        -v "${ModelsDir}:/models" `
        -v "${OutputDir}:/output" `
        python:3.11-slim `
        bash -c $dockerScript

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "  ❌ 下载失败（退出码: $LASTEXITCODE）" -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "✅ 下载完成" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""

    # 读取结果
    $resultsFile = Join-Path $OutputDir "download_results.json"
    if (Test-Path $resultsFile) {
        $results = Get-Content $resultsFile -Raw | ConvertFrom-Json

        Write-Host "📊 最终统计:" -ForegroundColor Cyan
        Write-Host "  ✅ 成功: $($results.success.Count) 个模型" -ForegroundColor Green
        Write-Host "  ❌ 失败: $($results.failed.Count) 个模型" -ForegroundColor Red
        Write-Host ""

        if ($results.success.Count -gt 0) {
            Write-Host "  成功的模型:" -ForegroundColor Green
            foreach ($name in $results.success) {
                Write-Host "    - $name" -ForegroundColor Gray
            }
            Write-Host ""
        }

        if ($results.failed.Count -gt 0) {
            Write-Host "  失败的模型:" -ForegroundColor Red
            foreach ($item in $results.failed) {
                Write-Host "    - $($item.name)" -ForegroundColor Gray
                Write-Host "      错误: $($item.error)" -ForegroundColor DarkGray
            }
            Write-Host ""
        }
    }

    # 统计模型大小
    if (Test-Path $ModelsDir) {
        $totalSize = (Get-ChildItem $ModelsDir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
        Write-Host "📦 模型总大小: $([math]::Round($totalSize, 1)) MB" -ForegroundColor Cyan
        Write-Host ""

        Write-Host "📋 已下载的模型:" -ForegroundColor Cyan
        Get-ChildItem $ModelsDir -Directory | ForEach-Object {
            $modelSize = (Get-ChildItem $_.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
            Write-Host "   - $($_.Name): $([math]::Round($modelSize, 1)) MB" -ForegroundColor Gray
        }
    }

    Write-Host ""
    Write-Host "🚀 下一步: 测试模型" -ForegroundColor Yellow
    Write-Host "   .\scripts\2026-02-15\06-test-paddlespeech-docker.ps1" -ForegroundColor Gray
    Write-Host ""

} catch {
    Write-Host ""
    Write-Host "  ❌ 执行失败: $_" -ForegroundColor Red
    Write-Host ""
    exit 1
}
