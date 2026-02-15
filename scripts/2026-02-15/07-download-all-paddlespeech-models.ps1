#Requires -Version 7.0
<#
.SYNOPSIS
    批量下载所有PaddleSpeech TTS模型
.DESCRIPTION
    下载所有官方PaddleSpeech中文TTS模型到本地
.EXAMPLE
    .\07-download-all-paddlespeech-models.ps1
.NOTES
    2026-02-15 06:15: 创建 - 批量下载所有模型
#>

$ErrorActionPreference = "Stop"

# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# ============================================================
# 配置
# ============================================================
$ProjectRoot = "E:\2025\3_gongkongji\belt_control_system"
$ModelsDir = Join-Path $ProjectRoot "libs\tts_models\paddlespeech"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PaddleSpeech 所有模型批量下载" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 模型列表
# ============================================================
$models = @(
    # ===== 中文模型（必须） =====
    @{
        Name = "FastSpeech2-CSMSC (女声)"
        Category = "必须"
        Files = @(
            @{
                Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_csmsc_ckpt_1.4.0.zip"
                FileName = "fastspeech2_csmsc_ckpt_1.4.0.zip"
                Size = "116 MB"
            }
        )
    },
    @{
        Name = "PWG-CSMSC (声码器)"
        Category = "必须"
        Files = @(
            @{
                Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_csmsc_ckpt_0.5.zip"
                FileName = "pwgan_csmsc_ckpt_0.5.zip"
                Size = "5 MB"
            }
        )
    },

    # ===== 多说话人模型（推荐，含男声） =====
    @{
        Name = "FastSpeech2-AISHELL3 (多说话人)"
        Category = "推荐"
        Files = @(
            @{
                Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_aishell3_ckpt_1.1.0.zip"
                FileName = "fastspeech2_aishell3_ckpt_1.1.0.zip"
                Size = "120 MB"
            }
        )
    },
    @{
        Name = "PWG-AISHELL3 (声码器)"
        Category = "推荐"
        Files = @(
            @{
                Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_aishell3_ckpt_0.5.zip"
                FileName = "pwgan_aishell3_ckpt_0.5.zip"
                Size = "5 MB"
            }
        )
    },

    # ===== VITS模型（高质量） =====
    @{
        Name = "VITS-CSMSC (女声，高质量)"
        Category = "高质量"
        Files = @(
            @{
                Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/vits/vits_csmsc_ckpt_1.4.0.zip"
                FileName = "vits_csmsc_ckpt_1.4.0.zip"
                Size = "400 MB"
            }
        )
    },
    @{
        Name = "VITS-AISHELL3 (多说话人，高质量)"
        Category = "高质量"
        Files = @(
            @{
                Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/vits/vits_aishell3_ckpt_1.1.0.zip"
                FileName = "vits_aishell3_ckpt_1.1.0.zip"
                Size = "500 MB"
            }
        )
    },

    # ===== HiFiGAN声码器（可选） =====
    @{
        Name = "HiFiGAN-CSMSC (高质量声码器)"
        Category = "可选"
        Files = @(
            @{
                Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/hifigan/hifigan_csmsc_ckpt_0.1.1.zip"
                FileName = "hifigan_csmsc_ckpt_0.1.1.zip"
                Size = "50 MB"
            }
        )
    },
    @{
        Name = "HiFiGAN-AISHELL3 (高质量声码器)"
        Category = "可选"
        Files = @(
            @{
                Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/hifigan/hifigan_aishell3_ckpt_0.2.0.zip"
                FileName = "hifigan_aishell3_ckpt_0.2.0.zip"
                Size = "50 MB"
            }
        )
    },

    # ===== 其他模型 =====
    @{
        Name = "SpeedySpeech-CSMSC (快速)"
        Category = "可选"
        Files = @(
            @{
                Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/speedyspeech/speedyspeech_csmsc_ckpt_0.5.0.zip"
                FileName = "speedyspeech_csmsc_ckpt_0.5.0.zip"
                Size = "12 MB"
            }
        )
    },
    @{
        Name = "FastSpeech2-Mix (中英混合)"
        Category = "可选"
        Files = @(
            @{
                Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_mix_ckpt_1.2.0.zip"
                FileName = "fastspeech2_mix_ckpt_1.2.0.zip"
                Size = "120 MB"
            }
        )
    },
    @{
        Name = "FastSpeech2-Canton (粤语)"
        Category = "可选"
        Files = @(
            @{
                Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_canton_ckpt_0.1.0.zip"
                FileName = "fastspeech2_canton_ckpt_0.1.0.zip"
                Size = "115 MB"
            }
        )
    },
    @{
        Name = "PWG-Canton (粤语声码器)"
        Category = "可选"
        Files = @(
            @{
                Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_canton_ckpt_0.1.0.zip"
                FileName = "pwgan_canton_ckpt_0.1.0.zip"
                Size = "5 MB"
            }
        )
    }
)

# ============================================================
# 准备目录
# ============================================================
Write-Host "[1/3] 准备目标目录..." -ForegroundColor Yellow

if (-not (Test-Path $ModelsDir)) {
    New-Item -ItemType Directory -Path $ModelsDir -Force | Out-Null
    Write-Host "  ✅ 创建模型目录" -ForegroundColor Green
} else {
    Write-Host "  ✅ 模型目录已存在" -ForegroundColor Green
}

Write-Host ""

# ============================================================
# 显示下载计划
# ============================================================
Write-Host "[2/3] 下载计划..." -ForegroundColor Yellow
Write-Host ""

$totalSize = 0
$totalFiles = 0

foreach ($model in $models) {
    Write-Host "  [$($model.Category)] $($model.Name)" -ForegroundColor Cyan
    foreach ($file in $model.Files) {
        Write-Host "    - $($file.FileName) ($($file.Size))" -ForegroundColor Gray
        $totalFiles++
    }
}

Write-Host ""
Write-Host "  📊 总计: $totalFiles 个文件" -ForegroundColor Cyan
Write-Host "  📦 预计总大小: 约 1.5 GB" -ForegroundColor Cyan
Write-Host "  ⏳ 预计时间: 20-30 分钟（取决于网络速度）" -ForegroundColor Cyan
Write-Host ""

# 询问用户
Write-Host "是否开始下载？(Y/N)" -ForegroundColor Yellow
$response = Read-Host

if ($response -ne "Y" -and $response -ne "y") {
    Write-Host "  取消下载" -ForegroundColor Gray
    exit 0
}

Write-Host ""

# ============================================================
# 开始下载
# ============================================================
Write-Host "[3/3] 开始下载模型..." -ForegroundColor Yellow
Write-Host ""

$downloadedCount = 0
$skippedCount = 0
$failedCount = 0

foreach ($model in $models) {
    Write-Host "  📥 $($model.Name)" -ForegroundColor Cyan

    foreach ($file in $model.Files) {
        $zipFile = Join-Path $ModelsDir $file.FileName
        $extractDir = [System.IO.Path]::GetFileNameWithoutExtension($file.FileName)
        $extractPath = Join-Path $ModelsDir $extractDir

        # 检查是否已下载
        if (Test-Path $extractPath) {
            Write-Host "    ⚠️  已存在，跳过: $($file.FileName)" -ForegroundColor Yellow
            $skippedCount++
            continue
        }

        try {
            # 下载
            Write-Host "    ⏳ 下载中: $($file.FileName) ($($file.Size))..." -ForegroundColor Gray
            Invoke-WebRequest -Uri $file.Url -OutFile $zipFile -UseBasicParsing -TimeoutSec 600

            # 解压
            Write-Host "    📂 解压中..." -ForegroundColor Gray
            Expand-Archive -Path $zipFile -DestinationPath $extractPath -Force

            # 删除zip
            Remove-Item $zipFile -Force

            Write-Host "    ✅ 完成: $($file.FileName)" -ForegroundColor Green
            $downloadedCount++

        } catch {
            Write-Host "    ❌ 失败: $($file.FileName)" -ForegroundColor Red
            Write-Host "    错误: $_" -ForegroundColor Red
            $failedCount++
        }
    }

    Write-Host ""
}

# ============================================================
# 完成
# ============================================================
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ 下载完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "📊 下载统计:" -ForegroundColor Cyan
Write-Host "  ✅ 成功: $downloadedCount 个文件" -ForegroundColor Green
Write-Host "  ⚠️  跳过: $skippedCount 个文件" -ForegroundColor Yellow
if ($failedCount -gt 0) {
    Write-Host "  ❌ 失败: $failedCount 个文件" -ForegroundColor Red
}
Write-Host ""

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
