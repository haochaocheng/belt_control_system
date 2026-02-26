#Requires -Version 7.0
<#
.SYNOPSIS
    同步 TTS 模型文件到设备的持久化目录
.DESCRIPTION
    1. 检测 Windows 上的 tts_models 目录
    2. 计算文件哈希，与上次部署比较
    3. 只在有变化时同步到设备
    4. 解压到 /home/linaro/belt-control-data/tts_models
    5. 设置正确的权限
.PARAMETER DeviceIP
    设备 IP 地址（支持简写，如 188 自动扩展为 192.168.10.188）
.PARAMETER Force
    强制重新同步（忽略哈希缓存）
.EXAMPLE
    .\02-sync-tts-models.ps1 188
.EXAMPLE
    .\02-sync-tts-models.ps1 192.168.10.188 -Force
.NOTES
    2026-02-13 16:30: 创建 - TTS 模型文件单独同步，使用 Volume 映射
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$DeviceIP,

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# ============================================================
# 配置
# ============================================================
$ProjectRoot = "E:\2025\3_gongkongji\belt_control_system"
# ✅ 2026-02-26 14:00 [Phase 7.47.9]: 修复源目录路径
# 原因：libs/tts_models 只有 vits_csmsc，完整的 PaddleSpeech 模型在 tts_models 目录
# $ModelsSourceDir = Join-Path $ProjectRoot "libs\tts_models"  # 旧路径（不完整）
$ModelsSourceDir = Join-Path $ProjectRoot "tts_models"  # 新路径（完整模型）
$CacheFile = Join-Path $env:TEMP "tts-models-sync-cache.json"
$DeviceUser = "linaro"

# 扩展 IP 地址（支持简写）
if ($DeviceIP -match '^\d{1,3}$') {
    $DeviceIP = "192.168.10.$DeviceIP"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  TTS 模型文件同步到设备" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  源目录: $ModelsSourceDir" -ForegroundColor White
Write-Host "  目标设备: ${DeviceUser}@${DeviceIP}" -ForegroundColor White
Write-Host ""

# ============================================================
# Step 1: 检查源目录
# ============================================================
Write-Host "[1/6] 检查源目录..." -ForegroundColor Yellow

if (-not (Test-Path $ModelsSourceDir)) {
    Write-Host "  ⚠️ 警告：tts_models 目录不存在：$ModelsSourceDir" -ForegroundColor Yellow
    Write-Host "  首次运行时，模型会在设备上自动下载" -ForegroundColor Cyan
    Write-Host "  如果已有模型文件，请将其放在：$ModelsSourceDir" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  跳过同步，继续部署..." -ForegroundColor Yellow
    exit 0
}

# 统计模型文件
$modelFiles = Get-ChildItem -Path $ModelsSourceDir -Recurse -File -ErrorAction SilentlyContinue
$totalSize = ($modelFiles | Measure-Object -Property Length -Sum).Sum
$totalSizeMB = [math]::Round($totalSize / 1MB, 2)

Write-Host "  ✅ 找到 $($modelFiles.Count) 个模型文件" -ForegroundColor Green
Write-Host "  📊 总大小: ${totalSizeMB} MB" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Step 2: 计算文件哈希（检测变化）
# ============================================================
Write-Host "[2/6] 检测文件变化..." -ForegroundColor Yellow

# 计算当前哈希
$hashBuilder = [System.Text.StringBuilder]::new()
foreach ($file in $modelFiles | Sort-Object FullName) {
    $relativePath = $file.FullName.Substring($ModelsSourceDir.Length + 1)
    $fileHash = (Get-FileHash -Path $file.FullName -Algorithm MD5).Hash
    [void]$hashBuilder.Append("$relativePath|$fileHash|")
}
$currentHash = (Get-FileHash -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($hashBuilder.ToString()))) -Algorithm MD5).Hash

# 检查缓存
$needSync = $true
if ((Test-Path $CacheFile) -and (-not $Force)) {
    $cache = Get-Content $CacheFile -Raw | ConvertFrom-Json
    if ($cache.modelsHash -eq $currentHash -and $cache.deviceIP -eq $DeviceIP) {
        Write-Host "  ✅ 模型文件未变化，跳过同步" -ForegroundColor Green
        Write-Host "  上次同步: $($cache.timestamp)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  提示：使用 -Force 参数强制重新同步" -ForegroundColor Yellow
        Write-Host ""
        exit 0
    }
}

Write-Host "  📝 检测到模型文件变化，需要同步" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Step 3: 打包模型文件
# ============================================================
Write-Host "[3/6] 打包模型文件..." -ForegroundColor Yellow

$packStart = Get-Date
$zipFileName = "tts_models_$(Get-Date -Format 'yyyyMMdd_HHmmss').zip"
$zipFilePath = Join-Path $env:TEMP $zipFileName

try {
    Compress-Archive -Path "$ModelsSourceDir\*" -DestinationPath $zipFilePath -Force
    $zipSize = (Get-Item $zipFilePath).Length
    $zipSizeMB = [math]::Round($zipSize / 1MB, 2)
    Write-Host "  ✅ 打包完成: ${zipSizeMB} MB" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "  ❌ 打包失败: $_" -ForegroundColor Red
    exit 1
}

# ============================================================
# Step 4: 上传到设备
# ============================================================
Write-Host "[4/6] 上传到设备..." -ForegroundColor Yellow

$uploadStart = Get-Date
try {
    scp -o StrictHostKeyChecking=no $zipFilePath "${DeviceUser}@${DeviceIP}:/tmp/$zipFileName"
    if ($LASTEXITCODE -ne 0) {
        throw "SCP 上传失败"
    }
    $uploadElapsed = (Get-Date) - $uploadStart
    Write-Host "  ✅ 上传完成（耗时 $($uploadElapsed.TotalSeconds.ToString('F1'))s）" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "  ❌ 上传失败: $_" -ForegroundColor Red
    Remove-Item $zipFilePath -Force
    exit 1
}

# ============================================================
# Step 5: 在设备上解压
# ============================================================
Write-Host "[5/6] 在设备上解压..." -ForegroundColor Yellow

$extractScript = @"
#!/bin/bash
set -e

# 创建目标目录
mkdir -p /home/linaro/belt-control-data/tts_models

# 解压（覆盖现有文件）
echo "  解压模型文件..."
unzip -o /tmp/$zipFileName -d /home/linaro/belt-control-data/tts_models

# 设置权限
echo "  设置权限..."
chmod -R 755 /home/linaro/belt-control-data/tts_models

# 清理临时文件
rm -f /tmp/$zipFileName

echo "  ✅ 解压完成"
"@

try {
    $extractScript | ssh -o StrictHostKeyChecking=no "${DeviceUser}@${DeviceIP}" "bash -s"
    if ($LASTEXITCODE -ne 0) {
        throw "解压失败"
    }
    Write-Host "  ✅ 解压完成" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "  ❌ 解压失败: $_" -ForegroundColor Red
    Remove-Item $zipFilePath -Force
    exit 1
}

# ============================================================
# Step 6: 更新同步缓存
# ============================================================
Write-Host "[6/6] 更新同步缓存..." -ForegroundColor Yellow

$cacheData = @{
    modelsHash = $currentHash
    timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    fileCount = $modelFiles.Count
    totalSizeMB = $totalSizeMB
    deviceIP = $DeviceIP
}
$cacheData | ConvertTo-Json | Set-Content $CacheFile -Encoding UTF8

Write-Host "  ✅ 缓存已更新" -ForegroundColor Green
Write-Host ""

# 清理本地 zip 文件
Remove-Item $zipFilePath -Force

# ============================================================
# 完成
# ============================================================
$totalElapsed = (Get-Date) - $packStart
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ TTS 模型文件同步完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  同步了 $($modelFiles.Count) 个文件（${totalSizeMB} MB）" -ForegroundColor White
Write-Host "  总耗时: $($totalElapsed.TotalSeconds.ToString('F1'))s" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ 后续容器重启不会丢失模型文件（使用 Volume 映射）" -ForegroundColor Green
Write-Host "✅ 应用编译不再包含模型文件（镜像更小，构建更快）" -ForegroundColor Green
Write-Host ""
Write-Host "📝 容器启动时需要添加 Volume 映射：" -ForegroundColor Yellow
Write-Host "  -v /home/linaro/belt-control-data/tts_models:/root/.paddlespeech:rw" -ForegroundColor Gray
Write-Host ""
