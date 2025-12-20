# 直接部署已编译的二进制文件到设备188
param(
    [string]$TargetDevice = "192.168.10.188"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deploy Pre-compiled ARM64 Binary" -ForegroundColor Cyan
Write-Host "Target: $TargetDevice" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

$ProjectRoot = "e:/2025/3_gongkongji/belt_control_system"

# Step 1: Find compiled binary
Write-Host "`n[1/4] Locating compiled binary..." -ForegroundColor Green

$binaryPath = "e:/2025/3_gongkongji/belt_control_system/build_rk3588_new/bin_arm64/belt_control_system"

if (-not (Test-Path $binaryPath)) {
    # Try other locations
    $altPaths = @(
        "$ProjectRoot/build_rk3588/bin_arm64/belt_control_system",
        "$ProjectRoot/build_rk3588_fixed/bin_arm64/belt_control_system",
        "$ProjectRoot/build_rk3588_mali_fix/bin_arm64/belt_control_system"
    )

    foreach ($path in $altPaths) {
        if (Test-Path $path) {
            $binaryPath = $path
            break
        }
    }
}

if (Test-Path $binaryPath) {
    $size = (Get-Item $binaryPath).Length / 1MB
    Write-Host "  Found: $binaryPath"
    Write-Host "  Size: $([Math]::Round($size, 2)) MB" -ForegroundColor Gray
} else {
    Write-Host "  ERROR: No compiled binary found!" -ForegroundColor Red
    exit 1
}

# Step 2: Create runtime Docker image
Write-Host "`n[2/4] Creating runtime Docker image..." -ForegroundColor Green

$deployContext = "$ProjectRoot/docker_runtime_deploy"
if (Test-Path $deployContext) {
    Remove-Item -Recurse -Force $deployContext
}
New-Item -ItemType Directory -Path $deployContext | Out-Null

# Create Dockerfile
$dockerContent = @'
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libqt6core6t64 \
    libqt6gui6t64 \
    libqt6widgets6t64 \
    libqt6network6t64 \
    libqt6qml6 \
    libqt6quick6 \
    qml6-module-qtquick \
    qml6-module-qtquick-controls \
    qml6-module-qtmultimedia \
    libgles2-mesa \
    libegl1-mesa \
    libasound2 \
    libpulse0 \
    libssl3t64 \
    fonts-noto-cjk \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy application files
COPY belt_control_system /app/
COPY config /app/config/
COPY libs/tts_models /app/libs/tts_models/
COPY libs/sherpa-onnx /app/libs/sherpa-onnx/

# Set permissions
RUN chmod +x /app/belt_control_system

# Create startup script
RUN echo '#!/bin/bash' > /app/start.sh && \
    echo 'export QT_QPA_PLATFORM=${QT_QPA_PLATFORM:-eglfs}' >> /app/start.sh && \
    echo 'export QT_QPA_EGLFS_PHYSICAL_WIDTH=${SCREEN_WIDTH:-1920}' >> /app/start.sh && \
    echo 'export QT_QPA_EGLFS_PHYSICAL_HEIGHT=${SCREEN_HEIGHT:-1080}' >> /app/start.sh && \
    echo 'export LD_LIBRARY_PATH=/app/libs/sherpa-onnx/lib:$LD_LIBRARY_PATH' >> /app/start.sh && \
    echo 'cd /app' >> /app/start.sh && \
    echo 'exec ./belt_control_system "$@"' >> /app/start.sh && \
    chmod +x /app/start.sh

ENTRYPOINT ["/app/start.sh"]
'@

$dockerContent | Out-File -Encoding UTF8 "$deployContext/Dockerfile"

# Copy files
Copy-Item $binaryPath "$deployContext/belt_control_system"

# Copy config if exists
if (Test-Path "$ProjectRoot/config") {
    Copy-Item -Recurse "$ProjectRoot/config" "$deployContext/"
}

# Copy TTS models and Sherpa-ONNX
if (Test-Path "$ProjectRoot/libs/tts_models") {
    New-Item -ItemType Directory -Path "$deployContext/libs" -Force | Out-Null
    Copy-Item -Recurse "$ProjectRoot/libs/tts_models" "$deployContext/libs/"
}

if (Test-Path "$ProjectRoot/libs/sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared") {
    Copy-Item -Recurse "$ProjectRoot/libs/sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared" "$deployContext/libs/sherpa-onnx"
}

# Build Docker image
Write-Host "  Building Docker image..." -ForegroundColor Yellow
docker build -t belt-control-app:arm64 $deployContext

if ($LASTEXITCODE -ne 0) {
    Write-Error "Docker build failed"
    exit 1
}

Write-Host "  [OK] Docker image built successfully" -ForegroundColor Green

# Step 3: Export and transfer
Write-Host "`n[3/4] Exporting and transferring to device..." -ForegroundColor Green

$exportFile = "$ProjectRoot/belt-control-arm64.tar"
Write-Host "  Exporting image..." -ForegroundColor Yellow
docker save -o $exportFile belt-control-app:arm64

$fileSize = (Get-Item $exportFile).Length / 1MB
Write-Host "  Image size: $([Math]::Round($fileSize, 2)) MB" -ForegroundColor Gray

Write-Host "  Transferring to $TargetDevice..." -ForegroundColor Yellow
scp $exportFile "pi@${TargetDevice}:/tmp/"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Transfer failed"
    Remove-Item $exportFile
    exit 1
}

# Step 4: Deploy on device
Write-Host "`n[4/4] Deploying on device..." -ForegroundColor Green

$deployCommands = @'
#!/bin/bash
echo "Loading Docker image..."
sudo docker load -i /tmp/belt-control-arm64.tar

echo "Stopping old container..."
sudo docker stop belt-control 2>/dev/null || true
sudo docker rm belt-control 2>/dev/null || true

echo "Starting new container..."
sudo docker run -d \
    --name belt-control \
    --restart unless-stopped \
    --privileged \
    -v /dev:/dev \
    -v /sys:/sys \
    -e QT_QPA_PLATFORM=eglfs \
    -e SCREEN_WIDTH=1920 \
    -e SCREEN_HEIGHT=1080 \
    belt-control-app:arm64

echo "Checking status..."
sudo docker ps | grep belt-control

echo "Cleaning up..."
rm /tmp/belt-control-arm64.tar

echo "Deployment complete!"
'@

$deployCommands | ssh "pi@${TargetDevice}" "bash -s"

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n[OK] Deployment successful!" -ForegroundColor Green
    Write-Host "`nUseful commands:" -ForegroundColor Cyan
    Write-Host "  View logs: ssh pi@$TargetDevice 'sudo docker logs -f belt-control'" -ForegroundColor Gray
    Write-Host "  Shell access: ssh pi@$TargetDevice 'sudo docker exec -it belt-control bash'" -ForegroundColor Gray
    Write-Host "  Stop: ssh pi@$TargetDevice 'sudo docker stop belt-control'" -ForegroundColor Gray
    Write-Host "  Restart: ssh pi@$TargetDevice 'sudo docker restart belt-control'" -ForegroundColor Gray
} else {
    Write-Error "Deployment failed"
}

# Cleanup
Remove-Item $exportFile -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $deployContext -ErrorAction SilentlyContinue

Write-Host "`n[OK] All tasks completed!" -ForegroundColor Green