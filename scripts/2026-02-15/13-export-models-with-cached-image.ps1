#Requires -Version 5.1
<#
.SYNOPSIS
    使用缓存的Docker镜像导出PaddleSpeech模型
.DESCRIPTION
    先构建包含PaddleSpeech的Docker镜像（一次性），然后使用该镜像导出模型
    避免每次都重新安装PaddleSpeech导致的网络超时问题
.EXAMPLE
    .\13-export-models-with-cached-image.ps1
.NOTES
    2026-02-15 14:30: 创建 - 使用缓存镜像避免重复安装
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
$ImageName = "paddlespeech-exporter:latest"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  导出PaddleSpeech模型（缓存镜像版）" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 准备目录
# ============================================================
Write-Host "[1/4] 准备目录..." -ForegroundColor Yellow

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
# 检查Docker镜像是否存在
# ============================================================
Write-Host "[2/4] 检查Docker镜像..." -ForegroundColor Yellow

$imageExists = docker images -q $ImageName 2>$null

if ($imageExists) {
    Write-Host "  ✅ 找到缓存镜像: $ImageName" -ForegroundColor Green
    Write-Host "  💡 如需重新构建，请先删除镜像: docker rmi $ImageName" -ForegroundColor Cyan
} else {
    Write-Host "  ⚠️  未找到缓存镜像，开始构建..." -ForegroundColor Yellow
    Write-Host ""

    # ============================================================
    # 构建Docker镜像（一次性）
    # ============================================================
    Write-Host "  🐳 构建Docker镜像（这可能需要5-10分钟）..." -ForegroundColor Cyan

    # 创建Dockerfile
    $dockerfile = @"
FROM python:3.11-slim

# 安装编译工具
RUN apt-get update -qq && \
    apt-get install -y build-essential -qq && \
    rm -rf /var/lib/apt/lists/*

# 安装Python依赖（使用清华镜像源）
RUN pip install --no-cache-dir \
    paddlepaddle==3.0.0 \
    paddlespeech \
    soundfile \
    -i https://pypi.tuna.tsinghua.edu.cn/simple

# 设置工作目录
WORKDIR /app

# 应用aistudio_sdk补丁
RUN python3 -c "import aistudio_sdk.hub as hub; hub.download = lambda *args, **kwargs: None"

CMD ["/bin/bash"]
"@

    $dockerfilePath = Join-Path $OutputDir "Dockerfile.paddlespeech"
    $dockerfile | Out-File -FilePath $dockerfilePath -Encoding utf8 -NoNewline

    Write-Host "  📝 Dockerfile已创建: $dockerfilePath" -ForegroundColor Gray
    Write-Host ""

    try {
        & docker build -t $ImageName -f $dockerfilePath $OutputDir

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
}

Write-Host ""

# ============================================================
# 创建Python下载脚本
# ============================================================
Write-Host "[3/4] 准备下载脚本..." -ForegroundColor Yellow

$pythonScript = @"
import sys
import os

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
print(f'📁 模型已保存到: /root/.paddlespeech')
"@

# 保存Python脚本
$pythonScriptPath = Join-Path $OutputDir "export_models.py"
$pythonScript | Out-File -FilePath $pythonScriptPath -Encoding utf8 -NoNewline

Write-Host "  ✅ 下载脚本已创建" -ForegroundColor Green
Write-Host ""

# ============================================================
# 运行Docker容器导出模型
# ============================================================
Write-Host "[4/4] 开始导出模型..." -ForegroundColor Yellow
Write-Host ""
Write-Host "  🐳 启动Docker容器..." -ForegroundColor Cyan
Write-Host ""

try {
    & docker run --rm `
        -v "${ModelsDir}:/models" `
        -v "${OutputDir}:/output" `
        $ImageName `
        bash -c @"
set -e

echo '  🚀 开始导出模型...'
python3 /output/export_models.py

echo ''
echo '  📦 复制模型到挂载目录...'
if [ -d /root/.paddlespeech ]; then
    echo '  📂 找到模型缓存目录'
    du -sh /root/.paddlespeech 2>/dev/null || echo '  (无法统计大小)'

    echo '  📋 模型列表:'
    ls -lh /root/.paddlespeech/ 2>/dev/null || echo '  (无法列出)'

    echo '  🔄 复制中...'
    cp -rv /root/.paddlespeech/* /models/ 2>&1 || echo '  ⚠️  复制失败'

    echo '  ✅ 模型已复制到: /models'
else
    echo '  ⚠️  未找到模型缓存目录'
    exit 1
fi

echo ''
echo '  📊 挂载目录内容:'
ls -lh /models/ 2>/dev/null || echo '  (空)'
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
    $items = Get-ChildItem $ModelsDir -Recurse -File -ErrorAction SilentlyContinue

    if ($items) {
        $totalSize = ($items | Measure-Object -Property Length -Sum).Sum / 1GB

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
    } else {
        Write-Host "⚠️  模型目录为空，导出可能失败" -ForegroundColor Yellow
        Write-Host "📁 检查目录: $ModelsDir" -ForegroundColor Cyan
    }
}

Write-Host ""
