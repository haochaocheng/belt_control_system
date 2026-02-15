#Requires -Version 7.0
<#
.SYNOPSIS
    上传 TTS 模型文件夹到 RK3588 设备
.DESCRIPTION
    将本机的 TTS 模型文件夹（5个子文件夹）上传到设备的 /home/pi/belt-control-data/models/tts_models/
.PARAMETER DeviceIP
    设备 IP 地址（支持简写，如 188 自动扩展为 192.168.10.188）
.EXAMPLE
    .\31-upload-tts-models.ps1 188
.EXAMPLE
    .\31-upload-tts-models.ps1 192.168.10.188
.NOTES
    2026-02-15 21:00: 创建 - 使用 scp 递归上传文件夹
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$DeviceIP
)

# UTF-8 with BOM
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# ============================================================
# 配置
# ============================================================
$ProjectRoot = "E:\2025\3_gongkongji\belt_control_system"
$SourceDir = Join-Path $ProjectRoot "tts_models"
$DeviceUser = "pi"
$TargetDir = "/home/pi/belt-control-data/models/tts_models"

# 需要上传的文件夹（排除压缩包）
$FoldersToUpload = @(
    "coqui",
    "melotts",
    "paddlespeech",
    "paddlespeech_offline",
    "piper"
)

# 扩展 IP 地址（支持简写）
if ($DeviceIP -match '^\d{1,3}$') {
    $DeviceIP = "192.168.10.$DeviceIP"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  上传 TTS 模型到 RK3588 设备" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  源目录: $SourceDir" -ForegroundColor White
Write-Host "  目标设备: ${DeviceUser}@${DeviceIP}" -ForegroundColor White
Write-Host "  目标路径: $TargetDir" -ForegroundColor White
Write-Host ""

# ============================================================
# Step 1: 检查源目录
# ============================================================
Write-Host "[1/4] 检查源目录..." -ForegroundColor Yellow

if (-not (Test-Path $SourceDir)) {
    Write-Host "  ❌ 错误：源目录不存在：$SourceDir" -ForegroundColor Red
    exit 1
}

# 检查每个文件夹是否存在
$missingFolders = @()
foreach ($folder in $FoldersToUpload) {
    $folderPath = Join-Path $SourceDir $folder
    if (-not (Test-Path $folderPath)) {
        $missingFolders += $folder
    }
}

if ($missingFolders.Count -gt 0) {
    Write-Host "  ⚠️  警告：以下文件夹不存在，将跳过：" -ForegroundColor Yellow
    foreach ($folder in $missingFolders) {
        Write-Host "    - $folder" -ForegroundColor Gray
    }
    # 从上传列表中移除不存在的文件夹
    $FoldersToUpload = $FoldersToUpload | Where-Object { $_ -notin $missingFolders }
}

Write-Host "  ✅ 将上传 $($FoldersToUpload.Count) 个文件夹" -ForegroundColor Green
Write-Host ""

# ============================================================
# Step 2: 测试设备连接
# ============================================================
Write-Host "[2/4] 测试设备连接..." -ForegroundColor Yellow

$testConnection = ssh -o ConnectTimeout=5 "${DeviceUser}@${DeviceIP}" "echo 'OK'" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ 无法连接到设备：${DeviceUser}@${DeviceIP}" -ForegroundColor Red
    Write-Host "  请检查：" -ForegroundColor Yellow
    Write-Host "    1. 设备 IP 地址是否正确" -ForegroundColor Gray
    Write-Host "    2. 设备是否在线" -ForegroundColor Gray
    Write-Host "    3. SSH 服务是否运行" -ForegroundColor Gray
    exit 1
}

Write-Host "  ✅ 设备连接成功" -ForegroundColor Green
Write-Host ""

# ============================================================
# Step 3: 创建目标目录
# ============================================================
Write-Host "[3/4] 创建目标目录..." -ForegroundColor Yellow

ssh "${DeviceUser}@${DeviceIP}" "mkdir -p $TargetDir" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ 创建目标目录失败" -ForegroundColor Red
    exit 1
}

Write-Host "  ✅ 目标目录已准备" -ForegroundColor Green
Write-Host ""

# ============================================================
# Step 4: 上传文件夹
# ============================================================
Write-Host "[4/4] 上传文件夹..." -ForegroundColor Yellow
Write-Host ""

$totalFolders = $FoldersToUpload.Count
$currentFolder = 0
$startTime = Get-Date

foreach ($folder in $FoldersToUpload) {
    $currentFolder++
    $folderPath = Join-Path $SourceDir $folder

    # 计算文件夹大小
    $folderSize = (Get-ChildItem -Path $folderPath -Recurse -File | Measure-Object -Property Length -Sum).Sum
    $folderSizeMB = [math]::Round($folderSize / 1MB, 2)

    Write-Host "  [$currentFolder/$totalFolders] 上传 $folder ($folderSizeMB MB)..." -ForegroundColor Cyan

    # ❌ 2026-02-15 21:30: 修复 - 先删除目标文件夹（如果存在），避免部分上传导致的问题
    Write-Host "    清理目标文件夹..." -ForegroundColor Gray
    # ✅ 2026-02-15 21:45: 显示错误信息，不隐藏输出
    $cleanResult = ssh "${DeviceUser}@${DeviceIP}" "rm -rf $TargetDir/$folder" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    ⚠️  清理失败: $cleanResult" -ForegroundColor Yellow
    }

    # 使用 rsync 替代 scp（支持断点续传，更可靠）
    # -a: 归档模式（保留权限）
    # -v: 详细输出
    # -z: 压缩传输
    # --progress: 显示进度
    # --partial: 保留部分传输的文件（支持断点续传）
    Write-Host "    开始传输..." -ForegroundColor Gray

    # 检查 rsync 是否可用
    $rsyncAvailable = ssh "${DeviceUser}@${DeviceIP}" "which rsync" 2>&1

    if ($LASTEXITCODE -eq 0) {
        # 使用 rsync（更可靠）
        # ✅ 2026-02-15 21:45: 显示详细输出，便于调试
        Write-Host "    使用 rsync 传输..." -ForegroundColor Gray
        rsync -avz --progress "$folderPath/" "${DeviceUser}@${DeviceIP}:${TargetDir}/$folder/"
        $uploadResult = $LASTEXITCODE
    } else {
        # 回退到 scp
        # ✅ 2026-02-15 21:45: 显示详细输出，便于调试
        Write-Host "    rsync 不可用，使用 scp 传输..." -ForegroundColor Gray
        scp -r -C "$folderPath" "${DeviceUser}@${DeviceIP}:${TargetDir}/"
        $uploadResult = $LASTEXITCODE
    }

    if ($uploadResult -eq 0) {
        Write-Host "    ✅ $folder 上传成功" -ForegroundColor Green
    } else {
        Write-Host "    ❌ $folder 上传失败（退出码: $uploadResult）" -ForegroundColor Red
        Write-Host "    可能原因：" -ForegroundColor Yellow
        Write-Host "      1. 网络连接中断" -ForegroundColor Gray
        Write-Host "      2. 磁盘空间不足" -ForegroundColor Gray
        Write-Host "      3. 权限问题" -ForegroundColor Gray
        Write-Host ""
        Write-Host "    建议：重新运行脚本继续上传" -ForegroundColor Cyan
        exit 1
    }
}

Write-Host ""

# ============================================================
# Step 5: 设置权限
# ============================================================
Write-Host "[5/5] 设置权限..." -ForegroundColor Yellow

ssh "${DeviceUser}@${DeviceIP}" "sudo chown -R ${DeviceUser}:${DeviceUser} $TargetDir && sudo chmod -R 755 $TargetDir" 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✅ 权限设置成功" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  权限设置失败（可能需要手动设置）" -ForegroundColor Yellow
}

Write-Host ""

# ============================================================
# 完成
# ============================================================
$totalElapsed = (Get-Date) - $startTime
Write-Host "========================================" -ForegroundColor Green
Write-Host "✅ TTS 模型上传完成" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "  上传了 $totalFolders 个文件夹" -ForegroundColor White
Write-Host "  总耗时: $($totalElapsed.TotalMinutes.ToString('F1')) 分钟" -ForegroundColor Cyan
Write-Host ""
Write-Host "📝 验证上传结果：" -ForegroundColor Yellow
Write-Host "  ssh ${DeviceUser}@${DeviceIP} 'ls -lh $TargetDir'" -ForegroundColor Gray
Write-Host ""
