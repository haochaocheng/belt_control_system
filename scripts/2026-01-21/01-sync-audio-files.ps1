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
# 配置 linaro
# ============================================================
$ProjectRoot = "E:\2025\3_gongkongji\belt_control_system"
$AudioSourceDir = Join-Path $ProjectRoot "AUDIO"
$CacheFile = Join-Path $env:TEMP "audio-sync-cache.json"
$DeviceUser = "pi"

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

# ✅ 2026-01-21 修复：使用 7-Zip 替代 tar 和 Compress-Archive
# 原因：
#   1. Windows tar.exe 无法处理 # 等特殊字符（编码问题）
#   2. PowerShell Compress-Archive 不支持 UTF-8 中文文件名（CP437 编码）
#      导致解压后文件名乱码："1号皮带启动.mp3" → "хП╖ц▓┐..."
# 方案：使用 7-Zip 创建 UTF-8 编码的 zip 文件
$zipFileName = "audio-files-$(Get-Date -Format 'yyyyMMdd-HHmmss').zip"
$zipFilePath = Join-Path $env:TEMP $zipFileName

# 检查 7-Zip 是否安装
$7zipPath = "C:\Program Files\7-Zip\7z.exe"
if (-not (Test-Path $7zipPath)) {
    Write-Host "  ❌ 错误：未找到 7-Zip" -ForegroundColor Red
    Write-Host "  请下载安装：https://www.7-zip.org/" -ForegroundColor Yellow
    Write-Host "  或使用 winget install -e --id 7zip.7zip" -ForegroundColor Yellow
    exit 1
}

Write-Host "  正在打包 AUDIO 目录（使用 7-Zip UTF-8 编码）..." -ForegroundColor Gray

try {
    # 使用 7-Zip 创建 zip 文件（-tzip 格式，-mx5 压缩级别，-mcu=on UTF-8 编码）
    & $7zipPath a -tzip -mx5 -mcu=on "$zipFilePath" "$AudioSourceDir" | Out-Null

    if ($LASTEXITCODE -ne 0) {
        throw "7-Zip 打包失败（退出码: $LASTEXITCODE）"
    }

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

echo "  创建临时解压目录..."
rm -rf /tmp/audio-extract
mkdir -p /tmp/audio-extract

echo "  解压音频文件（zip 格式，UTF-8 编码）..."
# ❌ 2026-01-21 20:50 [修复] 设备 unzip 6.00 不支持 -O UTF-8 参数
# 旧代码：unzip -O UTF-8 -q ${remoteZipPath} -d /tmp/audio-extract/ 2>&1 | grep -v "mismatching" || true
# 修复：使用环境变量 LANG=C.UTF-8 确保 UTF-8 编码
# ✅ 2026-01-21: 7-Zip 使用 UTF-8 编码，通过环境变量设置解压编码
LANG=C.UTF-8 LC_ALL=C.UTF-8 unzip -q ${remoteZipPath} -d /tmp/audio-extract/ 2>&1 | grep -v "mismatching" || true

# ✅ 2026-01-21 修复：直接移动 AUDIO 目录，避免 mv * 对特殊字符的问题
echo "  移动到目标位置..."
if [ -d "/tmp/audio-extract/AUDIO" ]; then
    # 删除旧的 audio 目录（如果存在）
    rm -rf /home/${DeviceUser}/belt-control-data/audio
    # 直接移动整个 AUDIO 目录并重命名为 audio
    mv /tmp/audio-extract/AUDIO /home/${DeviceUser}/belt-control-data/audio
    echo "  ✅ 移动成功"
else
    echo "  ❌ 错误：解压后未找到 AUDIO 目录"
    exit 1
fi

# 清理临时目录
rm -rf /tmp/audio-extract

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
