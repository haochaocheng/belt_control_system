#Requires -Version 5.1
<#
.SYNOPSIS
    统计所有TTS模型文件
.DESCRIPTION
    检查四个TTS引擎的模型文件是否完整
.EXAMPLE
    .\26-check-all-tts-models.ps1
.NOTES
    2026-02-15 18:30: 创建 - 统计所有TTS模型
#>

$ErrorActionPreference = "Stop"

# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# ============================================================
# 配置
# ============================================================
$ProjectRoot = "E:\2025\3_gongkongji\belt_control_system"
$ModelsRoot = Join-Path $ProjectRoot "tts_models"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  四引擎 TTS 模型统计" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 1. PaddleSpeech
# ============================================================
Write-Host "[1/4] PaddleSpeech" -ForegroundColor Yellow

$paddleDir = Join-Path $ModelsRoot "paddlespeech_offline"
if (Test-Path $paddleDir) {
    $paddleSize = (Get-ChildItem $paddleDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
    Write-Host "  ✅ 模型大小: $([math]::Round($paddleSize, 2)) GB" -ForegroundColor Green
    Write-Host "  📁 位置: $paddleDir" -ForegroundColor Gray

    # 检查关键文件
    $fs2Model = Join-Path $paddleDir "models\fastspeech2_csmsc-zh\1.0"
    $pwgModel = Join-Path $paddleDir "models\pwgan_csmsc-zh\1.0"

    if ((Test-Path $fs2Model) -and (Test-Path $pwgModel)) {
        Write-Host "  ✅ 声学模型和声码器完整" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️  模型文件可能不完整" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ❌ 未找到模型" -ForegroundColor Red
}

Write-Host ""

# ============================================================
# 2. MeloTTS
# ============================================================
Write-Host "[2/4] MeloTTS" -ForegroundColor Yellow

$meloDir = Join-Path $ModelsRoot "melotts"
if (Test-Path $meloDir) {
    $meloSize = (Get-ChildItem $meloDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "  ✅ 模型大小: $([math]::Round($meloSize, 1)) MB" -ForegroundColor Green
    Write-Host "  📁 位置: $meloDir" -ForegroundColor Gray

    # 检查中文模型
    $zhCheckpoint = Join-Path $meloDir "MeloTTS-Chinese\checkpoint.pth"
    $zhConfig = Join-Path $meloDir "MeloTTS-Chinese\config.json"

    if ((Test-Path $zhCheckpoint) -and (Test-Path $zhConfig)) {
        $zhSize = (Get-Item $zhCheckpoint).Length / 1MB
        Write-Host "  ✅ 中文模型: $([math]::Round($zhSize, 1)) MB" -ForegroundColor Green
    } else {
        Write-Host "  ❌ 中文模型不完整" -ForegroundColor Red
    }

    # 检查英文模型
    $enCheckpoint = Join-Path $meloDir "MeloTTS-English\checkpoint.pth"
    $enConfig = Join-Path $meloDir "MeloTTS-English\config.json"

    if ((Test-Path $enCheckpoint) -and (Test-Path $enConfig)) {
        $enSize = (Get-Item $enCheckpoint).Length / 1MB
        Write-Host "  ✅ 英文模型: $([math]::Round($enSize, 1)) MB" -ForegroundColor Green
    } else {
        Write-Host "  ❌ 英文模型不完整" -ForegroundColor Red
    }
} else {
    Write-Host "  ❌ 未找到模型" -ForegroundColor Red
}

Write-Host ""

# ============================================================
# 3. Piper TTS
# ============================================================
Write-Host "[3/4] Piper TTS" -ForegroundColor Yellow

$piperDir = Join-Path $ModelsRoot "piper"
if (Test-Path $piperDir) {
    $piperSize = (Get-ChildItem $piperDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "  ✅ 模型大小: $([math]::Round($piperSize, 1)) MB" -ForegroundColor Green
    Write-Host "  📁 位置: $piperDir" -ForegroundColor Gray

    # 检查 ONNX 模型
    $onnxModel = Join-Path $piperDir "zh_CN-huayan-medium.onnx"
    $onnxConfig = Join-Path $piperDir "zh_CN-huayan-medium.onnx.json"

    if ((Test-Path $onnxModel) -and (Test-Path $onnxConfig)) {
        $onnxSize = (Get-Item $onnxModel).Length / 1MB
        Write-Host "  ✅ ONNX 模型: $([math]::Round($onnxSize, 1)) MB" -ForegroundColor Green
        Write-Host "  ✅ 配置文件: 已创建" -ForegroundColor Green
    } else {
        Write-Host "  ❌ 模型文件不完整" -ForegroundColor Red
    }
} else {
    Write-Host "  ❌ 未找到模型" -ForegroundColor Red
}

Write-Host ""

# ============================================================
# 4. Coqui TTS
# ============================================================
Write-Host "[4/4] Coqui TTS" -ForegroundColor Yellow

$coquiDir = Join-Path $ModelsRoot "coqui"
if (Test-Path $coquiDir) {
    $coquiSize = (Get-ChildItem $coquiDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "  ✅ 模型大小: $([math]::Round($coquiSize, 1)) MB" -ForegroundColor Green
    Write-Host "  📁 位置: $coquiDir" -ForegroundColor Gray

    # 检查模型文件
    $modelFile = Join-Path $coquiDir "tts_models--zh-CN--baker--tacotron2-DDC-GST\model_file.pth"
    $configFile = Join-Path $coquiDir "tts_models--zh-CN--baker--tacotron2-DDC-GST\config.json"

    if ((Test-Path $modelFile) -and (Test-Path $configFile)) {
        $modelSize = (Get-Item $modelFile).Length / 1MB
        Write-Host "  ✅ 模型文件: $([math]::Round($modelSize, 1)) MB" -ForegroundColor Green
    } else {
        Write-Host "  ❌ 模型文件不完整" -ForegroundColor Red
    }
} else {
    Write-Host "  ❌ 未找到模型" -ForegroundColor Red
}

Write-Host ""

# ============================================================
# 总结
# ============================================================
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ 模型统计完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

if (Test-Path $ModelsRoot) {
    $totalSize = (Get-ChildItem $ModelsRoot -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
    Write-Host "📦 模型总大小: $([math]::Round($totalSize, 2)) GB" -ForegroundColor Cyan
    Write-Host "📁 模型位置: $ModelsRoot" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "🚀 下一步: 复制模型到 RK3588" -ForegroundColor Yellow
    Write-Host "   scp -r $ModelsRoot linaro@192.168.10.188:/app/models/" -ForegroundColor Gray
    Write-Host ""
}
