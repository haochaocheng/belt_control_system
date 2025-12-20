# Docker deployment to device 188 (user: linaro)
param(
    [string]$Device = "192.168.10.188"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Docker Deployment to $Device (user: linaro)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$root = "e:/2025/3_gongkongji/belt_control_system"
$binary = "$root/build_rk3588_new/bin_arm64/belt_control_system"
$context = "$root/docker_deploy_188"

# Clean and create context
if (Test-Path $context) { Remove-Item -Recurse -Force $context }
New-Item -ItemType Directory $context | Out-Null

# Create minimal Dockerfile with correct Ubuntu 24.04 package names
@'
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y \
    libqt6core6t64 \
    libqt6gui6t64 \
    libqt6widgets6t64 \
    libqt6network6t64 \
    libqt6qml6 \
    libqt6quick6 \
    qml6-module-qtquick \
    qml6-module-qtquick-controls \
    libgles2 \
    libegl1 \
    libasound2t64 \
    libpulse0t64 \
    fonts-noto-cjk \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY belt_control_system /app/
RUN chmod +x /app/belt_control_system

ENV QT_QPA_PLATFORM=eglfs
ENV QT_QPA_EGLFS_PHYSICAL_WIDTH=1920
ENV QT_QPA_EGLFS_PHYSICAL_HEIGHT=1080

CMD ["/app/belt_control_system"]
'@ | Out-File -Encoding UTF8 "$context/Dockerfile"

# Copy binary
Copy-Item $binary "$context/"

# Build image
Write-Host "Building Docker image..." -ForegroundColor Yellow
docker build -t belt-app:arm64 $context

if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker build failed!" -ForegroundColor Red
    exit 1
}

# Export image
Write-Host "Exporting image..." -ForegroundColor Yellow
docker save -o "$root/belt-app.tar" belt-app:arm64

$size = (Get-Item "$root/belt-app.tar").Length / 1MB
Write-Host "Image size: $([Math]::Round($size, 2)) MB" -ForegroundColor Gray

# Transfer to device
Write-Host "Transferring to device..." -ForegroundColor Yellow
scp "$root/belt-app.tar" "linaro@${Device}:/tmp/"

if ($LASTEXITCODE -ne 0) {
    Write-Host "Transfer failed!" -ForegroundColor Red
    Remove-Item "$root/belt-app.tar"
    exit 1
}

# Deploy on device
Write-Host "Deploying on device..." -ForegroundColor Yellow
ssh "linaro@${Device}" @"
echo 'Loading Docker image...'
sudo docker load -i /tmp/belt-app.tar
echo 'Stopping old container...'
sudo docker stop belt-control 2>/dev/null || true
sudo docker rm belt-control 2>/dev/null || true
echo 'Starting new container...'
sudo docker run -d \
    --name belt-control \
    --restart unless-stopped \
    --privileged \
    -v /dev:/dev \
    -v /sys:/sys \
    belt-app:arm64
echo 'Container status:'
sudo docker ps | grep belt-control
echo 'Cleaning up...'
rm /tmp/belt-app.tar
echo 'Deployment complete!'
"@

# Cleanup
Remove-Item "$root/belt-app.tar" -ErrorAction SilentlyContinue
Remove-Item -Recurse $context -ErrorAction SilentlyContinue

Write-Host "`n[OK] Docker deployment complete!" -ForegroundColor Green
Write-Host "Commands:" -ForegroundColor Cyan
Write-Host "  View logs: ssh linaro@$Device 'sudo docker logs -f belt-control'" -ForegroundColor Gray
Write-Host "  Shell: ssh linaro@$Device 'sudo docker exec -it belt-control bash'" -ForegroundColor Gray
Write-Host "  Stop: ssh linaro@$Device 'sudo docker stop belt-control'" -ForegroundColor Gray