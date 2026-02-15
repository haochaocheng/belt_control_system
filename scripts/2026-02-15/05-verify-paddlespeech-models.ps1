#Requires -Version 7.0
<#
.SYNOPSIS
    验证 PaddleSpeech 模型是否正确下载
.DESCRIPTION
    检查模型文件完整性和大小
.EXAMPLE
    .\05-verify-paddlespeech-models.ps1
.NOTES
    2026-02-15 04:20: 创建 - 模型验证脚本
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
Write-Host "  PaddleSpeech 模型验证工具" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 检查模型目录
# ============================================================
Write-Host "[1/2] 检查模型目录..." -ForegroundColor Yellow

if (-not (Test-Path $ModelsDir)) {
    Write-Host "  ❌ 模型目录不存在: $ModelsDir" -ForegroundColor Red
    Write-Host "  请先运行下载脚本：" -ForegroundColor Yellow
    Write-Host "    .\scripts\2026-02-15\04-download-vits-model-direct.ps1" -ForegroundColor Gray
    exit 1
}

Write-Host "  ✅ 模型目录存在" -ForegroundColor Green
Write-Host ""

# ============================================================
# 检查 VITS 模型
# ============================================================
Write-Host "[2/2] 检查 VITS 模型..." -ForegroundColor Yellow

$vitsDir = Join-Path $ModelsDir "vits_csmsc_ckpt_1.4.0"

if (-not (Test-Path $vitsDir)) {
    Write-Host "  ❌ VITS 模型目录不存在" -ForegroundColor Red
    Write-Host "  请先运行下载脚本：" -ForegroundColor Yellow
    Write-Host "    .\scripts\2026-02-15\04-download-vits-model-direct.ps1" -ForegroundColor Gray
    exit 1
}

# 检查必需文件
$requiredFiles = @(
    @{
        Name = "default.yaml"
        MinSize = 1  # KB
        Description = "模型配置文件"
    },
    @{
        Name = "snapshot_iter_150000.pdz"
        MinSize = 300000  # KB (约300MB)
        Description = "模型权重文件"
    },
    @{
        Name = "phone_id_map.txt"
        MinSize = 1  # KB
        Description = "音素字典"
    }
)

$allFilesValid = $true

foreach ($file in $requiredFiles) {
    $filePath = Join-Path $vitsDir $file.Name

    if (-not (Test-Path $filePath)) {
        Write-Host "  ❌ 缺少文件: $($file.Name)" -ForegroundColor Red
        $allFilesValid = $false
        continue
    }

    $fileSize = (Get-Item $filePath).Length / 1KB

    if ($fileSize -lt $file.MinSize) {
        Write-Host "  ❌ 文件过小: $($file.Name) ($([math]::Round($fileSize / 1024, 1)) MB < $([math]::Round($file.MinSize / 1024, 1)) MB)" -ForegroundColor Red
        $allFilesValid = $false
        continue
    }

    Write-Host "  ✅ $($file.Name)" -ForegroundColor Green
    Write-Host "     大小: $([math]::Round($fileSize / 1024, 1)) MB" -ForegroundColor Gray
    Write-Host "     说明: $($file.Description)" -ForegroundColor Gray
}

Write-Host ""

# ============================================================
# 结果
# ============================================================
if ($allFilesValid) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "✅ 模型验证通过" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""

    # 统计总大小
    $totalSize = (Get-ChildItem $vitsDir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
    Write-Host "📊 模型总大小: $([math]::Round($totalSize, 1)) MB" -ForegroundColor Cyan
    Write-Host "📂 模型位置: $vitsDir" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "🚀 下一步: 测试语音合成" -ForegroundColor Yellow
    Write-Host "   .\scripts\2026-02-15\02-test-paddlespeech-vits.ps1" -ForegroundColor Gray
    Write-Host ""

    exit 0
} else {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "❌ 模型验证失败" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host ""

    Write-Host "💡 解决方法：" -ForegroundColor Yellow
    Write-Host "   1. 删除不完整的模型目录：" -ForegroundColor Yellow
    Write-Host "      Remove-Item '$vitsDir' -Recurse -Force" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   2. 重新下载模型：" -ForegroundColor Yellow
    Write-Host "      .\scripts\2026-02-15\04-download-vits-model-direct.ps1" -ForegroundColor Gray
    Write-Host ""

    exit 1
}
