#Requires -Version 7.0
<#
.SYNOPSIS
    同步音频文件到设备的持久化目录（只同步一次，有更新时重新同步）
.DESCRIPTION
    1. 检测 Windows 上的 AUDIO 目录
    2. 计算文件哈希，与上次部署比较
    3. 只在有变化时同步到设备
    4. 解压到 /home/linaro/belt-control-data/audio
    5. 设置正确的权限
.PARAMETER DeviceIP
    设备 IP 地址（支持简写，如 188 自动扩展为 192.168.10.188）
.PARAMETER Force
    强制重新同步（忽略哈希缓存）
.EXAMPLE
    .\01-sync-audio-files.ps1 188
.EXAMPLE
    .\01-sync-audio-files.ps1 192.168.10.188 -Force
.NOTES
    2026-01-21 15:00: 创建 - 音频文件单独同步，使用 Volume 映射
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
$AudioSourceDir = Join-Path $ProjectRoot "AUDIO"
$CacheFile = Join-Path $env:TEMP "audio-sync-cache.json"
$DeviceUser = "linaro"

# 扩展 IP 地址（支持简写）
if ($DeviceIP -match '^\d{1,3}$') {
    $DeviceIP = "192.168.10.$DeviceIP"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  音频文件同步到设备" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  源目录: $AudioSourceDir" -ForegroundColor White
Write-Host "  目标设备: ${DeviceUser}@${DeviceIP}" -ForegroundColor White
Write-Host ""

# ============================================================
# Step 1: 检查源目录
# ============================================================
Write-Host "[1/6] 检查源目录..." -ForegroundColor Yellow

if (-not (Test-Path $AudioSourceDir)) {
    Write-Host "  ❌ 错误：AUDIO 目录不存在：$AudioSourceDir" -ForegroundColor Red
    Write-Host "  请确保项目根目录下有 AUDIO 文件夹" -ForegroundColor Yellow
    exit 1
}

# 统计音频文件
$audioFiles = Get-ChildItem -Path $AudioSourceDir -Recurse -File -ErrorAction SilentlyContinue
$totalSize = ($audioFiles | Measure-Object -Property Length -Sum).Sum
$totalSizeMB = [math]::Round($totalSize / 1MB, 2)

Write-Host "  ✅ 找到 $($audioFiles.Count) 个音频文件" -ForegroundColor Green
Write-Host "  📊 总大小: ${totalSizeMB} MB" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Step 2: 计算文件哈希（检测变化）
# ============================================================
Write-Host "[2/6] 检测文件变化..." -ForegroundColor Yellow

# 使用目录树结构+文件大小作为快速哈希（避免读取大文件内容）
$hashInput = Get-ChildItem -Path $AudioSourceDir -Recurse -File |
             Select-Object FullName, Length, LastWriteTime |
             Sort-Object FullName |
             ForEach-Object { "$($_.FullName)|$($_.Length)|$($_.LastWriteTime.Ticks)" } |
             Out-String

$currentHash = (Get-FileHash -InputStream ([System.IO.MemoryStream]::new([System.Text.Encoding]::UTF8.GetBytes($hashInput))) -Algorithm MD5).Hash

Write-Host "  当前哈希: $currentHash" -ForegroundColor Gray

# 检查缓存
$needSync = $true
if ((Test-Path $CacheFile) -and -not $Force) {
    $cacheData = Get-Content $CacheFile | ConvertFrom-Json
    $previousHash = $cacheData.audioHash
    $previousTimestamp = $cacheData.timestamp

    if ($previousHash -eq $currentHash) {
        Write-Host "  ✅ 文件无变化（上次同步: $previousTimestamp）" -ForegroundColor Green
        Write-Host "  ℹ️  跳过同步（使用 -Force 强制重新同步）" -ForegroundColor Cyan
        $needSync = $false
    } else {
        Write-Host "  ⚠️  文件已变化，需要同步" -ForegroundColor Yellow
    }
} else {
    if ($Force) {
        Write-Host "  ⚡ 强制同步模式" -ForegroundColor Yellow
    } else {
        Write-Host "  ℹ️  首次同步" -ForegroundColor Cyan
    }
}
Write-Host ""

if (-not $needSync) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "✅ 音频文件已是最新版本" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    exit 0
}

# ============================================================
# Step 3: 打包音频文件
# ============================================================
Write-Host "[3/6] 打包音频文件..." -ForegroundColor Yellow
$packStart = Get-Date

# ✅ 2026-01-21 修复：使用 PowerShell Compress-Archive 替代 tar
# 原因：Windows tar.exe 无法处理包含 # 等特殊字符的目录名（编码问题）
# 方案：Compress-Archive 创建 zip 文件，Linux 用 unzip 解压
$zipFileName = "audio-files-$(Get-Date -Format 'yyyyMMdd-HHmmss').zip"
$zipFilePath = Join-Path $env:TEMP $zipFileName

Write-Host "  正在打包 AUDIO 目录（使用 Compress-Archive）..." -ForegroundColor Gray

try {
    # Compress-Archive 直接支持特殊字符，无需切换目录
    Compress-Archive -Path $AudioSourceDir -DestinationPath $zipFilePath -CompressionLevel Optimal -Force

    $zipSize = [math]::Round((Get-Item $zipFilePath).Length / 1MB, 2)
    $packElapsed = (Get-Date) - $packStart
    Write-Host "  ✅ 打包完成: ${zipSize} MB（耗时 $($packElapsed.TotalSeconds.ToString('F1'))s）" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "  ❌ 打包失败" -ForegroundColor Red
    Write-Host "  错误信息：$($_.Exception.Message)" -ForegroundColor Yellow
    exit 1
}

# ============================================================
# Step 4: 上传到设备
# ============================================================
Write-Host "[4/6] 上传到设备..." -ForegroundColor Yellow
$uploadStart = Get-Date

$remoteZipPath = "/tmp/$zipFileName"
scp $zipFilePath "${DeviceUser}@${DeviceIP}:${remoteZipPath}"

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ 上传失败" -ForegroundColor Red
    Remove-Item $zipFilePath -Force
    exit 1
}

$uploadElapsed = (Get-Date) - $uploadStart
Write-Host "  ✅ 上传完成（耗时 $($uploadElapsed.TotalSeconds.ToString('F1'))s）" -ForegroundColor Green
Write-Host ""

# ============================================================
# Step 5: 解压并设置权限
# ============================================================
Write-Host "[5/6] 解压并设置权限..." -ForegroundColor Yellow

$deployScript = @"
#!/bin/bash
set -e

echo "  创建目标目录..."
mkdir -p /home/${DeviceUser}/belt-control-data/audio

echo "  解压音频文件（zip 格式）..."
# ✅ 2026-01-21: Windows 使用 Compress-Archive 创建 zip，Linux 用 unzip 解压
unzip -q ${remoteZipPath} -d /home/${DeviceUser}/belt-control-data/

# 移动 AUDIO 目录内容到 audio 目录
echo "  整理目录结构..."
if [ -d "/home/${DeviceUser}/belt-control-data/AUDIO" ]; then
    # 移动 AUDIO/* 到 audio/
    mv /home/${DeviceUser}/belt-control-data/AUDIO/* /home/${DeviceUser}/belt-control-data/audio/ 2>/dev/null || true
    rmdir /home/${DeviceUser}/belt-control-data/AUDIO 2>/dev/null || true
fi

echo "  设置权限..."
sudo chown -R ${DeviceUser}:${DeviceUser} /home/${DeviceUser}/belt-control-data/audio
sudo chmod -R 755 /home/${DeviceUser}/belt-control-data/audio

echo "  清理临时文件..."
rm -f ${remoteZipPath}

echo "  ✅ 音频文件部署完成"

# 显示目录结构（前10个文件）
echo ""
echo "  音频目录内容（前10个）:"
find /home/${DeviceUser}/belt-control-data/audio -type f | head -10 | sed 's/^/    /'
TOTAL_FILES=$(find /home/${DeviceUser}/belt-control-data/audio -type f | wc -l)
echo "    ... 共 $TOTAL_FILES 个文件"
"@

# 使用 UTF-8 编码写入脚本
$tempScript = Join-Path $env:TEMP "deploy-audio.sh"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($tempScript, $deployScript, $utf8NoBom)

# 上传并执行脚本
scp $tempScript "${DeviceUser}@${DeviceIP}:/tmp/deploy-audio.sh" | Out-Null
ssh "${DeviceUser}@${DeviceIP}" "bash /tmp/deploy-audio.sh"

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ 部署失败" -ForegroundColor Red
    exit 1
}

Remove-Item $tempScript -Force
Write-Host ""

# ============================================================
# Step 6: 更新缓存
# ============================================================
Write-Host "[6/6] 更新同步缓存..." -ForegroundColor Yellow

$cacheData = @{
    audioHash = $currentHash
    timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    fileCount = $audioFiles.Count
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
Write-Host "✅ 音频文件同步完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  同步了 $($audioFiles.Count) 个文件（${totalSizeMB} MB）" -ForegroundColor White
Write-Host "  总耗时: $($totalElapsed.TotalSeconds.ToString('F1'))s" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ 后续容器重启不会丢失音频文件（使用 Volume 映射）" -ForegroundColor Green
Write-Host "✅ 应用编译不再包含音频文件（镜像更小，构建更快）" -ForegroundColor Green
Write-Host ""
Write-Host "下一步：运行应用编译" -ForegroundColor Yellow
Write-Host "  .\build-ubuntu24-apt.ps1 $DeviceIP" -ForegroundColor Gray
Write-Host ""
