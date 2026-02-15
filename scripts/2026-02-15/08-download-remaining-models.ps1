#Requires -Version 7.0
<#
.SYNOPSIS
    下载剩余的PaddleSpeech TTS模型（中文、中英混合、英文、粤语）
.DESCRIPTION
    根据已下载的模型，只下载还需要的中文、中英混合、英文和粤语模型
.EXAMPLE
    .\08-download-remaining-models.ps1
.NOTES
    2026-02-15 12:20: 创建 - 筛选下载剩余模型
#>

$ErrorActionPreference = "Stop"

# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# ============================================================
# 配置
# ============================================================
$ProjectRoot = "E:\2025\3_gongkongji\belt_control_system"
$ModelsDir = Join-Path $ProjectRoot "tts_models"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PaddleSpeech 剩余模型下载" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 已下载模型检查
# ============================================================
Write-Host "[1/4] 检查已下载模型..." -ForegroundColor Yellow
Write-Host ""

$existingModels = @(
    "fastspeech2_aishell3_ckpt_1.1.0",
    "hifigan_aishell3_ckpt_0.2.0",
    "hifigan_csmsc_ckpt_0.1.1",
    "tacotron2_csmsc_ckpt_0.2.0",
    "vits_csmsc_ckpt_1.4.0"
)

Write-Host "  ✅ 已下载的模型:" -ForegroundColor Green
foreach ($model in $existingModels) {
    Write-Host "     - $model" -ForegroundColor Gray
}
Write-Host ""

# ============================================================
# 需要下载的模型列表
# ============================================================
Write-Host "[2/4] 准备下载清单..." -ForegroundColor Yellow
Write-Host ""

$modelsToDownload = @(
    # ===== 中文基础模型（必须） =====
    @{
        Name = "FastSpeech2-CSMSC (中文女声)"
        Category = "必须"
        Priority = 1
        Files = @(
            @{
                Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_csmsc_ckpt_1.4.0.zip"
                FileName = "fastspeech2_csmsc_ckpt_1.4.0.zip"
                Size = "116 MB"
            },
            @{
                Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_csmsc_ckpt_0.5.zip"
                FileName = "pwgan_csmsc_ckpt_0.5.zip"
                Size = "5 MB"
            }
        )
    },
    @{
        Name = "PWG-AISHELL3 (声码器)"
        Category = "必须"
        Priority = 1
        Files = @(
            @{
                Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_aishell3_ckpt_0.5.zip"
                FileName = "pwgan_aishell3_ckpt_0.5.zip"
                Size = "5 MB"
            }
        )
    },

    # ===== 中英混合模型 =====
    @{
        Name = "FastSpeech2-Mix (中英混合)"
        Category = "中英混合"
        Priority = 2
        Files = @(
            @{
                Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_mix_ckpt_1.2.0.zip"
                FileName = "fastspeech2_mix_ckpt_1.2.0.zip"
                Size = "120 MB"
            }
        )
    },

    # ===== 英文模型 =====
    @{
        Name = "FastSpeech2-LJSpeech (英文女声)"
        Category = "英文"
        Priority = 2
        Files = @(
            @{
                Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_ljspeech_ckpt_1.4.0.zip"
                FileName = "fastspeech2_ljspeech_ckpt_1.4.0.zip"
                Size = "115 MB"
            },
            @{
                Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_ljspeech_ckpt_0.5.zip"
                FileName = "pwgan_ljspeech_ckpt_0.5.zip"
                Size = "5 MB"
            }
        )
    },
    @{
        Name = "FastSpeech2-VCTK (英文多说话人)"
        Category = "英文"
        Priority = 3
        Files = @(
            @{
                Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_vctk_ckpt_1.2.0.zip"
                FileName = "fastspeech2_vctk_ckpt_1.2.0.zip"
                Size = "120 MB"
            },
            @{
                Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_vctk_ckpt_0.5.zip"
                FileName = "pwgan_vctk_ckpt_0.5.zip"
                Size = "5 MB"
            }
        )
    },

    # ===== 粤语模型 =====
    @{
        Name = "FastSpeech2-Canton (粤语)"
        Category = "粤语"
        Priority = 2
        Files = @(
            @{
                Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/fastspeech2/fastspeech2_canton_ckpt_0.1.0.zip"
                FileName = "fastspeech2_canton_ckpt_0.1.0.zip"
                Size = "115 MB"
            },
            @{
                Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/pwgan/pwgan_canton_ckpt_0.1.0.zip"
                FileName = "pwgan_canton_ckpt_0.1.0.zip"
                Size = "5 MB"
            }
        )
    },

    # ===== 可选高质量模型 =====
    @{
        Name = "VITS-AISHELL3 (中文多说话人，高质量)"
        Category = "可选"
        Priority = 4
        Files = @(
            @{
                Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/vits/vits_aishell3_ckpt_1.1.0.zip"
                FileName = "vits_aishell3_ckpt_1.1.0.zip"
                Size = "500 MB"
            }
        )
    },
    @{
        Name = "SpeedySpeech-CSMSC (中文快速)"
        Category = "可选"
        Priority = 4
        Files = @(
            @{
                Url = "https://paddlespeech.bj.bcebos.com/Parakeet/released_models/speedyspeech/speedyspeech_csmsc_ckpt_0.5.0.zip"
                FileName = "speedyspeech_csmsc_ckpt_0.5.0.zip"
                Size = "12 MB"
            }
        )
    }
)

# 按优先级排序
$modelsToDownload = $modelsToDownload | Sort-Object Priority

# 显示下载计划
Write-Host "  📋 下载计划（按优先级）:" -ForegroundColor Cyan
Write-Host ""

$totalFiles = 0
foreach ($model in $modelsToDownload) {
    Write-Host "  [$($model.Category)] $($model.Name)" -ForegroundColor Cyan
    foreach ($file in $model.Files) {
        Write-Host "    - $($file.FileName) ($($file.Size))" -ForegroundColor Gray
        $totalFiles++
    }
}

Write-Host ""
Write-Host "  📊 总计: $totalFiles 个文件" -ForegroundColor Cyan
Write-Host "  📦 预计总大小: 约 1.1 GB" -ForegroundColor Cyan
Write-Host "  ⏳ 预计时间: 15-25 分钟（取决于网络速度）" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 询问用户
# ============================================================
Write-Host "[3/4] 确认下载..." -ForegroundColor Yellow
Write-Host ""
Write-Host "  是否开始下载？(Y/N)" -ForegroundColor Yellow
$response = Read-Host

if ($response -ne "Y" -and $response -ne "y") {
    Write-Host "  取消下载" -ForegroundColor Gray
    exit 0
}

Write-Host ""

# ============================================================
# 开始下载
# ============================================================
Write-Host "[4/4] 开始下载模型..." -ForegroundColor Yellow
Write-Host ""

$downloadedCount = 0
$skippedCount = 0
$failedCount = 0
$failedModels = @()

foreach ($model in $modelsToDownload) {
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
            $failedModels += @{
                Model = $model.Name
                File = $file.FileName
                Error = $_.Exception.Message
            }
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
    Write-Host ""
    Write-Host "  失败详情:" -ForegroundColor Red
    foreach ($failed in $failedModels) {
        Write-Host "    - $($failed.Model): $($failed.File)" -ForegroundColor Red
        Write-Host "      错误: $($failed.Error)" -ForegroundColor Gray
    }
}
Write-Host ""

# 统计模型大小
if (Test-Path $ModelsDir) {
    $totalSize = (Get-ChildItem $ModelsDir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "📦 模型总大小: $([math]::Round($totalSize, 1)) MB" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "📋 所有已下载的模型:" -ForegroundColor Cyan
    Get-ChildItem $ModelsDir -Directory | ForEach-Object {
        $modelSize = (Get-ChildItem $_.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
        Write-Host "   - $($_.Name): $([math]::Round($modelSize, 1)) MB" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "🚀 下一步: 测试模型" -ForegroundColor Yellow
Write-Host "   .\\scripts\\2026-02-15\\06-test-paddlespeech-docker.ps1" -ForegroundColor Gray
Write-Host ""
