#Requires -Version 5.1
<#
.SYNOPSIS
    使用缓存镜像下载MeloTTS模型
.DESCRIPTION
    使用预构建的Docker镜像下载MeloTTS模型
    避免重复安装依赖，快速下载
.EXAMPLE
    .\21-download-melotts-with-cache.ps1
.NOTES
    2026-02-15 16:45: 创建 - 使用缓存镜像下载MeloTTS模型
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
$TempDir = Join-Path $ProjectRoot "temp\melotts"
$ImageName = "melotts-downloader:latest"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  下载MeloTTS模型（缓存镜像版）" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 准备目录
# ============================================================
Write-Host "[1/4] 准备目录..." -ForegroundColor Yellow

if (-not (Test-Path $ModelsDir)) {
    New-Item -ItemType Directory -Path $ModelsDir -Force | Out-Null
}

if (-not (Test-Path $TempDir)) {
    New-Item -ItemType Directory -Path $TempDir -Force | Out-Null
}

Write-Host "  ✅ 目录准备完成" -ForegroundColor Green
Write-Host ""

# ============================================================
# 检查Docker镜像
# ============================================================
Write-Host "[2/4] 检查Docker镜像..." -ForegroundColor Yellow

$imageExists = docker images -q $ImageName 2>$null

if (-not $imageExists) {
    Write-Host "  ❌ 未找到镜像: $ImageName" -ForegroundColor Red
    Write-Host "  💡 请先运行: .\scripts\2026-02-15\20-build-melotts-image.ps1" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "  ✅ 找到缓存镜像: $ImageName" -ForegroundColor Green
Write-Host ""

# ============================================================
# 创建Python下载脚本
# ============================================================
Write-Host "[3/4] 开始下载模型..." -ForegroundColor Yellow
Write-Host ""

$pythonScript = @"
import os
import sys
from pathlib import Path
import shutil

print('  📂 初始化MeloTTS...')

try:
    from melo.api import TTS

    print('  ✅ MeloTTS加载成功')
    print('')

    # 下载中文模型
    print('  [1/2] 下载中文模型...')
    try:
        tts_zh = TTS(language='ZH', device='cpu')
        print('  ✅ 中文模型下载成功')

        # 测试生成音频
        print('  🔊 测试语音合成...')
        speaker_ids = tts_zh.hps.data.spk2id
        print(f'     可用说话人: {list(speaker_ids.keys())}')

        # 生成测试音频
        tts_zh.tts_to_file('你好，这是MeloTTS中文测试', speaker_ids['ZH'], '/output/melotts_zh_test.wav', speed=1.0)
        print('  ✅ 测试音频生成成功')

    except Exception as e:
        print(f'  ❌ 中文模型下载失败: {str(e)}')

    print('')

    # 下载英文模型
    print('  [2/2] 下载英文模型...')
    try:
        tts_en = TTS(language='EN', device='cpu')
        print('  ✅ 英文模型下载成功')

        # 测试生成音频
        print('  🔊 测试语音合成...')
        speaker_ids = tts_en.hps.data.spk2id
        print(f'     可用说话人: {list(speaker_ids.keys())}')

        # 生成测试音频
        tts_en.tts_to_file('Hello, this is MeloTTS English test', speaker_ids['EN-US'], '/output/melotts_en_test.wav', speed=1.0)
        print('  ✅ 测试音频生成成功')

    except Exception as e:
        print(f'  ❌ 英文模型下载失败: {str(e)}')

    print('')
    print('========================================')
    print('✅ MeloTTS模型下载完成')
    print('========================================')

    # 查找并复制模型文件
    print('')
    print('  📂 查找模型文件...')

    # MeloTTS模型保存在 ~/.cache/huggingface/hub/
    cache_dir = Path.home() / '.cache' / 'huggingface' / 'hub'
    if cache_dir.exists():
        print(f'  📁 缓存目录: {cache_dir}')

        # 复制到输出目录
        output_dir = Path('/output')
        copied_count = 0

        for model_dir in cache_dir.glob('models--myshell-ai--*'):
            print(f'  📦 复制模型: {model_dir.name}')
            dest_dir = output_dir / model_dir.name
            if dest_dir.exists():
                shutil.rmtree(dest_dir)
            shutil.copytree(model_dir, dest_dir)
            copied_count += 1

        if copied_count > 0:
            print(f'  ✅ 已复制 {copied_count} 个模型目录')
        else:
            print('  ⚠️  未找到模型文件')
    else:
        print('  ⚠️  未找到缓存目录')

except Exception as e:
    print(f'❌ 错误: {str(e)}')
    import traceback
    traceback.print_exc()
    sys.exit(1)
"@

# 保存Python脚本
$pythonScriptPath = Join-Path $TempDir "download_melotts.py"
$pythonScript | Out-File -FilePath $pythonScriptPath -Encoding utf8 -NoNewline

Write-Host "  🐳 启动Docker容器..." -ForegroundColor Cyan
Write-Host ""

try {
    & docker run --rm `
        -v "${ModelsDir}:/output" `
        $ImageName `
        python3 - <<'PYTHON_SCRIPT'
$pythonScript
PYTHON_SCRIPT

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "  ❌ 下载失败（退出码: $LASTEXITCODE）" -ForegroundColor Red
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
Write-Host "[4/4] 统计模型信息..." -ForegroundColor Yellow
Write-Host ""

if (Test-Path $ModelsDir) {
    $totalSize = (Get-ChildItem $ModelsDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB

    if ($totalSize -gt 0) {
        Write-Host "  📦 模型总大小: $([math]::Round($totalSize, 1)) MB" -ForegroundColor Cyan
        Write-Host "  📁 模型位置: $ModelsDir" -ForegroundColor Cyan
        Write-Host ""

        Write-Host "  📋 模型列表:" -ForegroundColor Cyan
        Get-ChildItem $ModelsDir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $modelSize = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
            if ($modelSize -gt 0) {
                Write-Host "     - $($_.Name): $([math]::Round($modelSize, 1)) MB" -ForegroundColor Gray
            }
        }

        Write-Host ""
        Write-Host "  🔊 测试音频:" -ForegroundColor Cyan
        Get-ChildItem $ModelsDir -Filter "*.wav" -ErrorAction SilentlyContinue | ForEach-Object {
            $audioSize = $_.Length / 1KB
            Write-Host "     - $($_.Name): $([math]::Round($audioSize, 1)) KB" -ForegroundColor Gray
        }
    } else {
        Write-Host "  ⚠️  未找到模型文件" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ 下载完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "🚀 下一步: 测试MeloTTS语音合成" -ForegroundColor Yellow
Write-Host ""
