# ✅ 2026-02-25 01:45 [测试]: 简化版设备构建脚本
# 用途：在设备 185 上构建基础镜像

$ErrorActionPreference = "Continue"
$DeviceIP = "192.168.10.185"
$DeviceUser = "linaro"
# 使用 SSH 密钥认证，无需密码
$ProjectRoot = "e:\2025\3_gongkongji\belt_control_system"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "在设备 $DeviceIP 上构建基础镜像" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 1. 上传 Dockerfile
Write-Host ""
Write-Host "步骤 1: 上传 Dockerfile..." -ForegroundColor Yellow
ssh "${DeviceUser}@${DeviceIP}" "mkdir -p /tmp/belt-control-build/docker/rk3588/tts_engines/paddlespeech"

scp "$ProjectRoot\Dockerfile.ubuntu24-base" "${DeviceUser}@${DeviceIP}:/tmp/belt-control-build/"
scp "$ProjectRoot\docker\rk3588\tts_engines\paddlespeech\requirements.txt" "${DeviceUser}@${DeviceIP}:/tmp/belt-control-build/docker/rk3588/tts_engines/paddlespeech/"

Write-Host "  文件上传完成" -ForegroundColor Green

# 2. 开始构建
Write-Host ""
Write-Host "步骤 2: 开始构建（预计 20-35 分钟）..." -ForegroundColor Yellow
Write-Host "  使用清华镜像源加速..." -ForegroundColor Cyan

$BuildCmd = @"
cd /tmp/belt-control-build && \
docker build \
    --pull=never \
    --network=host \
    --build-arg PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple \
    --build-arg PIP_TRUSTED_HOST=pypi.tuna.tsinghua.edu.cn \
    -t belt-control-base:latest \
    -f Dockerfile.ubuntu24-base \
    . 2>&1 | tee build.log
"@

Write-Host ""
Write-Host "开始时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green
$StartTime = Get-Date

# 执行构建（前台运行，可以看到实时输出）
ssh "${DeviceUser}@${DeviceIP}" $BuildCmd

$EndTime = Get-Date
$Duration = $EndTime - $StartTime

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "构建完成" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "结束时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Green
Write-Host "总耗时: $($Duration.TotalMinutes.ToString('F2')) 分钟" -ForegroundColor Green

# 3. 获取镜像信息
Write-Host ""
Write-Host "步骤 3: 获取镜像信息..." -ForegroundColor Yellow
$ImageSize = ssh "${DeviceUser}@${DeviceIP}" "docker images belt-control-base:latest --format '{{.Size}}'"
Write-Host "  镜像大小: $ImageSize" -ForegroundColor Cyan

Write-Host ""
Write-Host "测试完成" -ForegroundColor Green
