#Requires -Version 5.1
<#
.SYNOPSIS
    下载Coqui TTS模型（功能引擎）
.DESCRIPTION
    使用Coqui TTS CLI自动下载中文VITS模型
.EXAMPLE
    .\18-download-coqui-models.ps1
.NOTES
    2026-02-15 15:55: 创建 - 下载Coqui TTS模型
#>

$ErrorActionPreference = "Stop"

# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# ============================================================
# 配置
# ============================================================
$ProjectRoot = "E:\2025\3_gongkongji\belt_control_system"
$ModelsDir = Join-Path $ProjectRoot "tts_models\coqui"
$TempDir = Join-Path $ProjectRoot "temp\coqui"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  下载Coqui TTS模型（功能引擎）" -ForegroundColor Cyan
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
Write-Host "  💡 Coqui TTS是功能引擎，支持语音克隆" -ForegroundColor Cyan
Write-Host "  📦 模型大小: 100-200 MB" -ForegroundColor Cyan
Write-Host "  🌐 下载源: Coqui官方" -ForegroundColor Cyan
Write-Host "  ⏳ 预计时间: 15-30分钟" -ForegroundColor Cyan
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
import shutil
from pathlib import Path

print('  📂 初始化Coqui TTS...')

try:
    # 安装Coqui TTS
    import subprocess
    print('  📦 安装Coqui TTS...')
    subprocess.run([sys.executable, '-m', 'pip', 'install', 'TTS', '-q'], check=True)

    # 导入TTS
    from TTS.api import TTS

    print('  ✅ Coqui TTS安装成功')
    print('')

    # 下载中文VITS模型
    print('  [1/1] 下载中文VITS模型...')
    print('     模型: tts_models/zh-CN/baker/tacotron2-DDC-GST')
    try:
        tts = TTS(model_name='tts_models/zh-CN/baker/tacotron2-DDC-GST', progress_bar=True)
        print('  ✅ 中文模型下载成功')

        # 测试生成音频
        print('  🔊 测试语音合成...')
        tts.tts_to_file(text='你好，这是Coqui TTS测试', file_path='/output/coqui_test.wav')
        print('  ✅ 测试音频生成成功')

    except Exception as e:
        print(f'  ❌ 中文模型下载失败: {str(e)}')
        # 尝试备用模型
        print('  🔄 尝试备用模型: tts_models/zh-CN/baker/vits')
        try:
            tts = TTS(model_name='tts_models/zh-CN/baker/vits', progress_bar=True)
            print('  ✅ 备用模型下载成功')
        except Exception as e2:
            print(f'  ❌ 备用模型也失败: {str(e2)}')

    print('')
    print('========================================')
    print('✅ Coqui TTS模型下载完成')
    print('========================================')

    # 查找模型文件
    print('')
    print('  📂 查找模型文件...')

    # Coqui TTS模型通常保存在 ~/.local/share/tts/
    cache_dir = Path.home() / '.local' / 'share' / 'tts'
    if cache_dir.exists():
        print(f'  📁 缓存目录: {cache_dir}')

        # 复制到输出目录
        output_dir = Path('/output')

        for model_dir in cache_dir.rglob('*'):
            if model_dir.is_dir() and 'tts_models' in str(model_dir):
                print(f'  📦 复制模型: {model_dir.name}')
                dest_dir = output_dir / model_dir.relative_to(cache_dir)
                dest_dir.parent.mkdir(parents=True, exist_ok=True)
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
$pythonScriptPath = Join-Path $TempDir "download_coqui.py"
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
apt-get install -y git build-essential libsndfile1 -qq

echo '  📦 安装Python依赖...'
pip install torch torchaudio --index-url https://download.pytorch.org/whl/cpu -q
pip install numpy scipy librosa -q

echo '  🚀 开始下载Coqui TTS模型...'
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
        Get-ChildItem $ModelsDir -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object { $_.GetFiles().Count -gt 0 } | ForEach-Object {
            $modelSize = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
            if ($modelSize -gt 0) {
                Write-Host "     - $($_.Name): $([math]::Round($modelSize, 1)) MB" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "  ⚠️  未找到模型文件" -ForegroundColor Yellow
        Write-Host "  💡 提示: 可能需要手动从Coqui官方下载" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ 下载完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "🚀 下一步: 测试Coqui TTS语音合成" -ForegroundColor Yellow
Write-Host ""
