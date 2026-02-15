#Requires -Version 5.1
<#
.SYNOPSIS
    使用缓存镜像下载Coqui TTS模型
.DESCRIPTION
    使用预构建的Docker镜像下载Coqui TTS模型
    避免重复安装依赖，快速下载
.EXAMPLE
    .\23-download-coqui-with-cache.ps1
.NOTES
    2026-02-15 16:55: 创建 - 使用缓存镜像下载Coqui TTS模型
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
$ImageName = "coqui-tts-downloader:latest"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  下载Coqui TTS模型（缓存镜像版）" -ForegroundColor Cyan
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
    Write-Host "  💡 请先运行: .\scripts\2026-02-15\22-build-coqui-image.ps1" -ForegroundColor Yellow
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

print('  📂 初始化Coqui TTS...')

try:
    from TTS.api import TTS

    print('  ✅ Coqui TTS加载成功')
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

            # 测试生成音频
            print('  🔊 测试语音合成...')
            tts.tts_to_file(text='你好，这是Coqui TTS VITS测试', file_path='/output/coqui_vits_test.wav')
            print('  ✅ 测试音频生成成功')

        except Exception as e2:
            print(f'  ❌ 备用模型也失败: {str(e2)}')

    print('')
    print('========================================')
    print('✅ Coqui TTS模型下载完成')
    print('========================================')

    # 查找并复制模型文件
    print('')
    print('  📂 查找模型文件...')

    # Coqui TTS模型保存在 ~/.local/share/tts/
    cache_dir = Path.home() / '.local' / 'share' / 'tts'
    if cache_dir.exists():
        print(f'  📁 缓存目录: {cache_dir}')

        # 复制到输出目录
        output_dir = Path('/output')
        copied_count = 0

        for model_dir in cache_dir.rglob('*'):
            if model_dir.is_dir() and 'tts_models' in str(model_dir):
                rel_path = model_dir.relative_to(cache_dir)
                print(f'  📦 复制模型: {rel_path}')
                dest_dir = output_dir / rel_path
                dest_dir.parent.mkdir(parents=True, exist_ok=True)
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
$pythonScriptPath = Join-Path $TempDir "download_coqui.py"
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
        Get-ChildItem $ModelsDir -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object { $_.GetFiles().Count -gt 0 } | ForEach-Object {
            $modelSize = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
            if ($modelSize -gt 0) {
                Write-Host "     - $($_.FullName.Replace($ModelsDir, '')): $([math]::Round($modelSize, 1)) MB" -ForegroundColor Gray
            }
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
