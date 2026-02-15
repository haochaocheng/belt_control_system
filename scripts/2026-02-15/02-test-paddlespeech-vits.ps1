#Requires -Version 7.0
<#
.SYNOPSIS
    测试PaddleSpeech VITS离线推理
.DESCRIPTION
    使用已下载的VITS模型测试语音合成功能
.EXAMPLE
    .\02-test-paddlespeech-vits.ps1
.NOTES
    2026-02-15 02:50: 创建 - 测试VITS离线推理
#>

$ErrorActionPreference = "Stop"

# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# ============================================================
# 配置
# ============================================================
$ProjectRoot = "E:\2025\3_gongkongji\belt_control_system"
$ModelDir = Join-Path $ProjectRoot "libs\tts_models\paddlespeech\vits_csmsc\vits_csmsc_ckpt_1.4.0"
$ScriptPath = Join-Path $ProjectRoot "tts_engines\paddlespeech_offline.py"
$OutputPath = Join-Path $ProjectRoot "test_output.wav"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PaddleSpeech VITS 离线推理测试" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Step 1: 检查模型文件
# ============================================================
Write-Host "[1/3] 检查模型文件..." -ForegroundColor Yellow

if (-not (Test-Path $ModelDir)) {
    Write-Host "  ❌ 模型目录不存在: $ModelDir" -ForegroundColor Red
    Write-Host "  请先运行: .\scripts\2026-02-15\01-download-paddlespeech-models-offline.ps1" -ForegroundColor Yellow
    exit 1
}

$requiredFiles = @("default.yaml", "snapshot_iter_150000.pdz", "phone_id_map.txt")
foreach ($file in $requiredFiles) {
    $filePath = Join-Path $ModelDir $file
    if (-not (Test-Path $filePath)) {
        Write-Host "  ❌ 缺少文件: $file" -ForegroundColor Red
        exit 1
    }
    Write-Host "  ✅ 找到文件: $file" -ForegroundColor Green
}

Write-Host ""

# ============================================================
# Step 2: 检查Python环境
# ============================================================
Write-Host "[2/3] 检查Python环境..." -ForegroundColor Yellow

$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
    Write-Host "  ❌ 未找到Python" -ForegroundColor Red
    exit 1
}

$pythonVersion = & python --version 2>&1
Write-Host "  ✅ Python版本: $pythonVersion" -ForegroundColor Green

# 检查paddlespeech
$checkPaddleSpeech = & python -c "import paddlespeech; print('OK')" 2>&1
if ($checkPaddleSpeech -notmatch "OK") {
    Write-Host "  ❌ paddlespeech未安装" -ForegroundColor Red
    Write-Host "  请运行: pip install paddlespeech" -ForegroundColor Yellow
    exit 1
}

Write-Host "  ✅ paddlespeech已安装" -ForegroundColor Green
Write-Host ""

# ============================================================
# Step 3: 测试语音合成
# ============================================================
Write-Host "[3/3] 测试语音合成..." -ForegroundColor Yellow

$testText = "你好，欢迎使用飞桨语音合成系统"
Write-Host "  📝 测试文本: $testText" -ForegroundColor Cyan

try {
    & python $ScriptPath `
        --model_dir $ModelDir `
        --text $testText `
        --output $OutputPath

    if (Test-Path $OutputPath) {
        $fileSize = (Get-Item $OutputPath).Length / 1KB
        Write-Host ""
        Write-Host "  ✅ 语音合成成功！" -ForegroundColor Green
        Write-Host "  📊 输出文件: $OutputPath" -ForegroundColor Cyan
        Write-Host "  📊 文件大小: $([math]::Round($fileSize, 1)) KB" -ForegroundColor Cyan
    } else {
        Write-Host "  ❌ 输出文件未生成" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "  ❌ 测试失败: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ 测试完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "🎵 播放音频: $OutputPath" -ForegroundColor Yellow
Write-Host ""
