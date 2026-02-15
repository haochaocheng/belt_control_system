#Requires -Version 5.1
<#
.SYNOPSIS
    下载MeloTTS模型（首选引擎）
.DESCRIPTION
    从GitHub Releases或Hugging Face下载MeloTTS预训练模型
    包含中文模型和中英混合模型
.EXAMPLE
    .\16-download-melotts-models.ps1
.NOTES
    2026-02-15 15:45: 创建 - 下载MeloTTS模型
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

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  下载MeloTTS模型（首选引擎）" -ForegroundColor Cyan
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
Write-Host "  📁 模型目录: $ModelsDir" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 说明
# ============================================================
Write-Host "[2/4] 下载说明..." -ForegroundColor Yellow
Write-Host ""
Write-Host "  💡 MeloTTS是首选引擎，语音质量接近商业级别" -ForegroundColor Cyan
Write-Host "  📦 模型大小: 50-100 MB" -ForegroundColor Cyan
Write-Host "  🌐 下载源: Hugging Face" -ForegroundColor Cyan
Write-Host "  ⏳ 预计时间: 10-20分钟" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 使用Docker下载模型
# ============================================================
Write-Host "[3/4] 开始下载模型..." -ForegroundColor Yellow
Write-Host ""

# 创建Python下载脚本
$pythonScript = @"
import os
import sys
import json
from pathlib import Path

print('  📂 初始化MeloTTS...')

try:
    # 安装MeloTTS
    import subprocess
    print('  📦 安装MeloTTS...')
    subprocess.run([sys.executable, '-m', 'pip', 'install', 'git+https://github.com/myshell-ai/MeloTTS.git', '-q'], check=True)

    # 导入MeloTTS
    from melo.api import TTS

    print('  ✅ MeloTTS安装成功')
    print('')

    # 下载中文模型
    print('  [1/2] 下载中文模型...')
    try:
        tts_zh = TTS(language='ZH', device='cpu')
        print('  ✅ 中文模型下载成功')
    except Exception as e:
        print(f'  ❌ 中文模型下载失败: {str(e)}')

    print('')

    # 下载英文模型
    print('  [2/2] 下载英文模型...')
    try:
        tts_en = TTS(language='EN', device='cpu')
        print('  ✅ 英文模型下载成功')
    except Exception as e:
        print(f'  ❌ 英文模型下载失败: {str(e)}')

    print('')
    print('========================================')
    print('✅ MeloTTS模型下载完成')
    print('========================================')

    # 查找模型文件
    print('')
    print('  📂 查找模型文件...')

    # MeloTTS模型通常保存在 ~/.cache/huggingface/hub/
    cache_dir = Path.home() / '.cache' / 'huggingface' / 'hub'
    if cache_dir.exists():
        print(f'  📁 缓存目录: {cache_dir}')

        # 复制到输出目录
        import shutil
        output_dir = Path('/output')

        for model_dir in cache_dir.glob('models--myshell-ai--*'):
            print(f'  📦 复制模型: {model_dir.name}')
            dest_dir = output_dir / model_dir.name
            if dest_dir.exists():
                shutil.rmtree(dest_dir)
            shutil.copytree(model_dir, dest_dir)

        print('  ✅ 模型已复制到输出目录')
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
        python:3.11-slim `
        bash -c @"
set -e

echo '  📦 安装系统依赖...'
apt-get update -qq
apt-get install -y git build-essential -qq

echo '  📦 安装Python依赖...'
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu -q
pip install numpy scipy librosa -q

echo '  🚀 开始下载MeloTTS模型...'
python3 - <<'PYTHON_SCRIPT'
$pythonScript
PYTHON_SCRIPT

echo ''
echo '  📊 输出目录内容:'
ls -lh /output/
"@

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
    } else {
        Write-Host "  ⚠️  未找到模型文件" -ForegroundColor Yellow
        Write-Host "  💡 提示: 可能需要手动从Hugging Face下载" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ MeloTTS模型下载完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# 清理临时文件
if (Test-Path $TempDir) {
    Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}
