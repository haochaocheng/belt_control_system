# ✅ 2026-02-25 15:25: 上传 pip 包并离线安装
# 用途：将本地下载的 pip 包上传到设备，离线安装

$ErrorActionPreference = "Continue"
$ProjectRoot = "e:\2025\3_gongkongji\belt_control_system"
$DownloadDir = "$ProjectRoot\pip_packages_arm64"
$DeviceIP = "192.168.10.185"
$DeviceUser = "linaro"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "上传 pip 包到设备 $DeviceIP" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 检查下载目录
if (-not (Test-Path $DownloadDir)) {
    Write-Host "错误: 下载目录不存在，请先运行 04-download-pip-packages.ps1" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "步骤 1: 在设备上创建目录..." -ForegroundColor Yellow
ssh "${DeviceUser}@${DeviceIP}" "mkdir -p /tmp/pip_packages"

Write-Host ""
Write-Host "步骤 2: 上传 pip 包..." -ForegroundColor Yellow
scp "$DownloadDir\*" "${DeviceUser}@${DeviceIP}:/tmp/pip_packages/"

Write-Host ""
Write-Host "步骤 3: 在设备上离线安装..." -ForegroundColor Yellow
ssh "${DeviceUser}@${DeviceIP}" "pip3 install --break-system-packages /tmp/pip_packages/*.whl"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "安装完成" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
