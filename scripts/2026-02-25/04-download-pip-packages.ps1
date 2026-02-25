# ✅ 2026-02-25 15:20: 本地下载 pip 依赖包
# 用途：在本地下载 ARM64 的 Python 依赖包，然后上传到设备离线安装

$ErrorActionPreference = "Stop"
$ProjectRoot = "e:\2025\3_gongkongji\belt_control_system"
$DownloadDir = "$ProjectRoot\pip_packages_arm64"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "下载 ARM64 Python 依赖包" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 创建下载目录
if (-not (Test-Path $DownloadDir)) {
    New-Item -ItemType Directory -Path $DownloadDir | Out-Null
}

Write-Host ""
Write-Host "步骤 1: 下载依赖包到 $DownloadDir ..." -ForegroundColor Yellow

# 使用 pip download 下载 ARM64 包
# --platform linux_aarch64 指定 ARM64 平台
# --python-version 312 指定 Python 3.12
# --only-binary :all: 只下载预编译包（避免源码包）
pip download `
    --dest $DownloadDir `
    --platform linux_aarch64 `
    --python-version 312 `
    --only-binary :all: `
    -i https://pypi.tuna.tsinghua.edu.cn/simple `
    paddlepaddle paddlespeech librosa soundfile pydub scipy numpy

Write-Host ""
Write-Host "步骤 2: 下载完成，文件列表：" -ForegroundColor Yellow
Get-ChildItem $DownloadDir -Name

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "下载完成" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "下载目录: $DownloadDir" -ForegroundColor Green
Write-Host ""
Write-Host "下一步：运行上传脚本" -ForegroundColor Yellow
Write-Host "  .\scripts\2026-02-25\05-upload-pip-packages.ps1" -ForegroundColor Yellow
