#Requires -Version 5.1
<#
.SYNOPSIS
    下载所有TTS引擎模型（统一脚本v2，缓存镜像版）
.DESCRIPTION
    按优先级顺序下载Piper TTS、MeloTTS、Coqui TTS三个引擎的模型
    使用缓存Docker镜像，避免重复安装依赖
.EXAMPLE
    .\24-download-all-tts-models-v2.ps1
.NOTES
    2026-02-15 17:00: 创建 - 统一下载所有TTS模型（缓存镜像版）
#>

$ErrorActionPreference = "Stop"

# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# ============================================================
# 配置
# ============================================================
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  下载所有TTS引擎模型 v2" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  📋 计划下载:" -ForegroundColor Cyan
Write-Host "     1. Piper TTS（性能引擎，10-50 MB，5-10分钟）" -ForegroundColor Gray
Write-Host "     2. MeloTTS（首选引擎，50-100 MB，2-3分钟）" -ForegroundColor Gray
Write-Host "     3. Coqui TTS（功能引擎，100-200 MB，2-3分钟）" -ForegroundColor Gray
Write-Host ""
Write-Host "  ⏳ 预计总时间: 9-16分钟（使用缓存镜像）" -ForegroundColor Yellow
Write-Host "  💡 首次运行需要先构建Docker镜像（25-35分钟）" -ForegroundColor Cyan
Write-Host ""

# 询问用户确认
$confirm = Read-Host "  是否继续？(Y/N)"
if ($confirm -ne 'Y' -and $confirm -ne 'y') {
    Write-Host "  ❌ 用户取消" -ForegroundColor Red
    exit 0
}

Write-Host ""

# ============================================================
# 检查并构建Docker镜像
# ============================================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  [0/3] 检查Docker镜像" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查MeloTTS镜像
$meloImageExists = docker images -q melotts-downloader:latest 2>$null
if (-not $meloImageExists) {
    Write-Host "  ⚠️  未找到MeloTTS镜像，开始构建..." -ForegroundColor Yellow
    $meloImageScript = Join-Path $ScriptDir "20-build-melotts-image.ps1"
    if (Test-Path $meloImageScript) {
        & $meloImageScript
    } else {
        Write-Host "  ❌ 未找到构建脚本: $meloImageScript" -ForegroundColor Red
    }
} else {
    Write-Host "  ✅ MeloTTS镜像已存在" -ForegroundColor Green
}

Write-Host ""

# 检查Coqui TTS镜像
$coquiImageExists = docker images -q coqui-tts-downloader:latest 2>$null
if (-not $coquiImageExists) {
    Write-Host "  ⚠️  未找到Coqui TTS镜像，开始构建..." -ForegroundColor Yellow
    $coquiImageScript = Join-Path $ScriptDir "22-build-coqui-image.ps1"
    if (Test-Path $coquiImageScript) {
        & $coquiImageScript
    } else {
        Write-Host "  ❌ 未找到构建脚本: $coquiImageScript" -ForegroundColor Red
    }
} else {
    Write-Host "  ✅ Coqui TTS镜像已存在" -ForegroundColor Green
}

Write-Host ""
Write-Host "  ⏸️  暂停5秒..." -ForegroundColor Gray
Start-Sleep -Seconds 5
Write-Host ""

# ============================================================
# 下载Piper TTS模型
# ============================================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  [1/3] 下载Piper TTS模型" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$piperScript = Join-Path $ScriptDir "17-download-piper-models.ps1"
if (Test-Path $piperScript) {
    try {
        & $piperScript
        Write-Host ""
        Write-Host "  ✅ Piper TTS模型下载完成" -ForegroundColor Green
    } catch {
        Write-Host ""
        Write-Host "  ❌ Piper TTS模型下载失败: $_" -ForegroundColor Red
        Write-Host "  💡 继续下载其他模型..." -ForegroundColor Yellow
    }
} else {
    Write-Host "  ⚠️  未找到Piper TTS下载脚本: $piperScript" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  ⏸️  暂停5秒..." -ForegroundColor Gray
Start-Sleep -Seconds 5
Write-Host ""

# ============================================================
# 下载MeloTTS模型
# ============================================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  [2/3] 下载MeloTTS模型" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$meloScript = Join-Path $ScriptDir "21-download-melotts-with-cache.ps1"
if (Test-Path $meloScript) {
    try {
        & $meloScript
        Write-Host ""
        Write-Host "  ✅ MeloTTS模型下载完成" -ForegroundColor Green
    } catch {
        Write-Host ""
        Write-Host "  ❌ MeloTTS模型下载失败: $_" -ForegroundColor Red
        Write-Host "  💡 继续下载其他模型..." -ForegroundColor Yellow
    }
} else {
    Write-Host "  ⚠️  未找到MeloTTS下载脚本: $meloScript" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  ⏸️  暂停5秒..." -ForegroundColor Gray
Start-Sleep -Seconds 5
Write-Host ""

# ============================================================
# 下载Coqui TTS模型
# ============================================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  [3/3] 下载Coqui TTS模型" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$coquiScript = Join-Path $ScriptDir "23-download-coqui-with-cache.ps1"
if (Test-Path $coquiScript) {
    try {
        & $coquiScript
        Write-Host ""
        Write-Host "  ✅ Coqui TTS模型下载完成" -ForegroundColor Green
    } catch {
        Write-Host ""
        Write-Host "  ❌ Coqui TTS模型下载失败: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  ⚠️  未找到Coqui TTS下载脚本: $coquiScript" -ForegroundColor Yellow
}

Write-Host ""

# ============================================================
# 统计总结
# ============================================================
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ 所有模型下载完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

$ProjectRoot = "E:\2025\3_gongkongji\belt_control_system"
$ModelsRoot = Join-Path $ProjectRoot "tts_models"

if (Test-Path $ModelsRoot) {
    Write-Host "📊 模型统计:" -ForegroundColor Cyan
    Write-Host ""

    # PaddleSpeech
    $paddleDir = Join-Path $ModelsRoot "paddlespeech_offline"
    if (Test-Path $paddleDir) {
        $paddleSize = (Get-ChildItem $paddleDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
        Write-Host "  ✅ PaddleSpeech: $([math]::Round($paddleSize, 2)) GB" -ForegroundColor Green
    } else {
        Write-Host "  ❌ PaddleSpeech: 未找到" -ForegroundColor Red
    }

    # MeloTTS
    $meloDir = Join-Path $ModelsRoot "melotts"
    if (Test-Path $meloDir) {
        $meloSize = (Get-ChildItem $meloDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
        if ($meloSize -gt 0) {
            Write-Host "  ✅ MeloTTS: $([math]::Round($meloSize, 1)) MB" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  MeloTTS: 0 MB（下载可能失败）" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ❌ MeloTTS: 未找到" -ForegroundColor Red
    }

    # Piper TTS
    $piperDir = Join-Path $ModelsRoot "piper"
    if (Test-Path $piperDir) {
        $piperSize = (Get-ChildItem $piperDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
        if ($piperSize -gt 0) {
            Write-Host "  ✅ Piper TTS: $([math]::Round($piperSize, 1)) MB" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  Piper TTS: 0 MB（下载可能失败）" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ❌ Piper TTS: 未找到" -ForegroundColor Red
    }

    # Coqui TTS
    $coquiDir = Join-Path $ModelsRoot "coqui"
    if (Test-Path $coquiDir) {
        $coquiSize = (Get-ChildItem $coquiDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
        if ($coquiSize -gt 0) {
            Write-Host "  ✅ Coqui TTS: $([math]::Round($coquiSize, 1)) MB" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  Coqui TTS: 0 MB（下载可能失败）" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  ❌ Coqui TTS: 未找到" -ForegroundColor Red
    }

    Write-Host ""

    # 总大小
    $totalSize = (Get-ChildItem $ModelsRoot -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1GB
    Write-Host "📦 模型总大小: $([math]::Round($totalSize, 2)) GB" -ForegroundColor Cyan
    Write-Host "📁 模型位置: $ModelsRoot" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "🚀 下一步: 测试TTS引擎" -ForegroundColor Yellow
Write-Host ""
