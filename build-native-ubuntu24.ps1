# Ubuntu 24.04 Native ARM64 Compilation for Device 188
# 使用 belt-control:v3.5-apt 镜像直接编译
# 避免交叉编译的GLIBC版本不兼容问题

$ErrorActionPreference = "Stop"
$DeviceIP = "192.168.10.188"  # 目标设备188

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Native Ubuntu 24.04 ARM64 Compilation" -ForegroundColor Cyan
Write-Host "Target Device: $DeviceIP" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: 清理构建目录
Write-Host "Step 1: Cleaning build directory..." -ForegroundColor Yellow
$BuildDir = "build_native_ubuntu24"
if (Test-Path $BuildDir) {
    Remove-Item -Recurse -Force $BuildDir
    Write-Host "  Build directory cleaned" -ForegroundColor Green
}
Write-Host ""

# Step 2: 在Ubuntu 24.04容器中进行本地ARM64编译
Write-Host "Step 2: Native ARM64 compilation in Ubuntu 24.04..." -ForegroundColor Yellow
Write-Host "  Using image: belt-control:v3.5-apt (GLIBC 2.39)" -ForegroundColor Gray
Write-Host "  This ensures all GLIBC dependencies are matched" -ForegroundColor Gray
Write-Host ""

$compileCmd = @"
apt-get update && apt-get install -y build-essential cmake pkg-config &&
cd /workspace &&
mkdir -p $BuildDir &&
cd $BuildDir &&
cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DENABLE_SHERPA_ONNX=ON \
  -DQt6_DIR=/opt/qt-raspi/lib/cmake/Qt6 \
  -DSHERPA_ONNX_ROOT=/opt/sherpa-onnx \
  .. &&
make -j\$(nproc) &&
echo '========================================' &&
echo 'Compilation successful!' &&
echo 'Binary location:' &&
find . -name 'belt_control_system' -type f
"@

# 挂载Qt6和Sherpa-ONNX库
docker run --rm `
    "--platform=linux/arm64" `
    "-v=${PWD}:/workspace" `
    "-v=${PWD}/docker/rk3588/qt-raspi:/opt/qt-raspi:ro" `
    "-v=${PWD}/libs/sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared:/opt/sherpa-onnx:ro" `
    "-w=/workspace" `
    "belt-control:v3.5-apt" `
    bash -c $compileCmd

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Compilation failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Compilation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# Step 3: 部署到设备188
Write-Host ""
Write-Host "Step 3: Deploy to device $DeviceIP..." -ForegroundColor Yellow
$choice = Read-Host "Deploy to device now? (y/n)"
if ($choice -eq 'y') {
    Write-Host "  Creating deployment package..." -ForegroundColor Gray

    # 打包二进制和依赖
    docker run --rm `
        -v "${PWD}:/workspace" `
        -w /workspace `
        belt-control:v3.5-apt `
        bash -c "cd $BuildDir && tar czf belt-control-native.tar.gz bin_arm64/"

    # 复制到设备
    Write-Host "  Copying to device..." -ForegroundColor Gray
    scp "$BuildDir/belt-control-native.tar.gz" "linaro@${DeviceIP}:/home/linaro/"

    # 在设备上解压并重启服务
    Write-Host "  Deploying on device..." -ForegroundColor Gray
    ssh "linaro@${DeviceIP}" @"
        cd /home/linaro &&
        tar xzf belt-control-native.tar.gz &&
        sudo systemctl stop belt-control || true &&
        sudo cp bin_arm64/belt_control_system /usr/local/bin/ &&
        sudo systemctl start belt-control &&
        echo 'Deployment complete!'
"@

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Deployment Complete!" -ForegroundColor Green
    Write-Host "Device: $DeviceIP" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
}