# Ubuntu 22.04 Native ARM64 Build Script
# 使用Ubuntu 22.04（GLIBC 2.35）避免版本不兼容问题
# 目标设备：188 (192.168.10.188)

$ErrorActionPreference = "Stop"
$DeviceIP = "192.168.10.188"  # 目标设备188

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Ubuntu 22.04 Native ARM64 Build" -ForegroundColor Cyan
Write-Host "Target Device: $DeviceIP" -ForegroundColor Cyan
Write-Host "GLIBC Version: 2.35 (Compatible)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: 检查Docker镜像
Write-Host "Step 1: Checking Docker images..." -ForegroundColor Yellow

# 检查v3.5-apt镜像是否存在
$aptImageExists = docker images --format "{{.Repository}}:{{.Tag}}" | Select-String "belt-control:v3.5-apt"
if ($aptImageExists) {
    Write-Host "  [OK] Found belt-control:v3.5-apt image" -ForegroundColor Green
    Write-Host "  This image contains all dependencies" -ForegroundColor Gray
} else {
    Write-Host "  [!] belt-control:v3.5-apt not found" -ForegroundColor Yellow
    Write-Host "  Building base Ubuntu 22.04 image instead..." -ForegroundColor Yellow

    # 创建Ubuntu 22.04基础镜像
    $dockerfileContent = @"
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai

# 安装基础构建工具
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    pkg-config \
    git \
    wget \
    && rm -rf /var/lib/apt/lists/*

# 安装Qt6开发包
RUN apt-get update && apt-get install -y \
    qt6-base-dev \
    qt6-declarative-dev \
    qt6-multimedia-dev \
    libqt6core6 \
    libqt6gui6 \
    libqt6widgets6 \
    libqt6qml6 \
    libqt6quick6 \
    && rm -rf /var/lib/apt/lists/*

# 安装必要的系统库
RUN apt-get update && apt-get install -y \
    libasound2-dev \
    libpulse-dev \
    libsdl2-dev \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libswscale-dev \
    libswresample-dev \
    libssl-dev \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
"@

    $dockerfileContent | Out-File -Encoding UTF8 "$ProjectRoot\Dockerfile.ubuntu22-native"

    Write-Host "  Building Ubuntu 22.04 base image..." -ForegroundColor Yellow
    docker build --platform linux/arm64 -f "$ProjectRoot\Dockerfile.ubuntu22-native" -t belt-control:ubuntu22-native "$ProjectRoot"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] Failed to build base image" -ForegroundColor Red
        exit 1
    }

    $ImageToUse = "belt-control:ubuntu22-native"
} else {
    $ImageToUse = "belt-control:v3.5-apt"
}

Write-Host ""

# Step 2: 清理构建目录
Write-Host "Step 2: Preparing build directory..." -ForegroundColor Yellow
$BuildDir = "build_ubuntu22_native"
if (Test-Path $BuildDir) {
    Remove-Item -Recurse -Force $BuildDir
    Write-Host "  Build directory cleaned" -ForegroundColor Green
}
Write-Host ""

# Step 3: 在Ubuntu 22.04容器中编译
Write-Host "Step 3: Native ARM64 compilation in Ubuntu 22.04..." -ForegroundColor Yellow
Write-Host "  Using image: $ImageToUse" -ForegroundColor Gray
Write-Host "  GLIBC Version: 2.35 (Compatible with 2.34-2.38 libs)" -ForegroundColor Gray
Write-Host ""

# 编译命令 - 使用系统Qt6而不是qt-raspi
$compileCmd = @"
apt-get update && apt-get install -y build-essential cmake pkg-config &&
cd /workspace &&
mkdir -p $BuildDir &&
cd $BuildDir &&
cmake \
  -DCMAKE_BUILD_TYPE=Release \
  -DENABLE_SHERPA_ONNX=ON \
  -DSHERPA_ONNX_ROOT=/opt/sherpa-onnx \
  .. &&
make -j\$(nproc) &&
echo '========================================' &&
echo 'Compilation successful!' &&
echo 'Binary location:' &&
ls -la bin_arm64/belt_control_system
"@

# 运行Docker容器进行编译
docker run --rm `
    "--platform=linux/arm64" `
    "-v=${PWD}:/workspace" `
    "-v=${PWD}/libs/sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared:/opt/sherpa-onnx:ro" `
    "-w=/workspace" `
    $ImageToUse `
    bash -c $compileCmd

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Compilation failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Compilation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

# Step 4: 创建部署包
Write-Host ""
Write-Host "Step 4: Creating deployment package..." -ForegroundColor Yellow

# 创建tar包
$TarFile = "belt-control-ubuntu22.tar.gz"
docker run --rm `
    -v "${PWD}:/workspace" `
    -w /workspace `
    ubuntu:22.04 `
    bash -c "cd $BuildDir && tar czf ../$TarFile bin_arm64/ lib/ plugins/ qml/ AUDIO/ 2>/dev/null || tar czf ../$TarFile bin_arm64/"

if (Test-Path $TarFile) {
    $fileSize = [math]::Round((Get-Item $TarFile).Length / 1MB, 2)
    Write-Host "  [OK] Package created: $TarFile (${fileSize}MB)" -ForegroundColor Green
} else {
    Write-Host "  [ERROR] Failed to create package" -ForegroundColor Red
    exit 1
}

# Step 5: 部署到设备188
Write-Host ""
Write-Host "Step 5: Deploy to device $DeviceIP..." -ForegroundColor Yellow
$choice = Read-Host "Deploy to device now? (y/n)"
if ($choice -eq 'y') {
    Write-Host "  Copying to device..." -ForegroundColor Gray
    scp $TarFile "linaro@${DeviceIP}:/home/linaro/"

    if ($LASTEXITCODE -ne 0) {
        Write-Host "  [ERROR] Failed to copy to device" -ForegroundColor Red
        exit 1
    }

    # 在设备上解压并运行
    Write-Host "  Deploying on device..." -ForegroundColor Gray
    ssh "linaro@${DeviceIP}" @"
        cd /home/linaro &&
        tar xzf $TarFile &&
        echo '========================================' &&
        echo 'Checking GLIBC version on device:' &&
        ldd --version | head -1 &&
        echo '========================================' &&
        echo 'Checking binary dependencies:' &&
        ldd bin_arm64/belt_control_system | head -10 &&
        echo '========================================' &&
        echo 'Ready to run. Use:' &&
        echo '  ./bin_arm64/belt_control_system'
"@

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Deployment Complete!" -ForegroundColor Green
    Write-Host "Device: $DeviceIP" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
}