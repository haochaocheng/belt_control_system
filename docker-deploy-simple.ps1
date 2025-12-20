# Simple Docker deployment script for ARM64 binary to device 188
param(
    [string]$Device = "192.168.10.188"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Docker Deployment to $Device" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$root = "e:/2025/3_gongkongji/belt_control_system"
$binary = "$root/build_rk3588_new/bin_arm64/belt_control_system"
$context = "$root/docker_deploy_minimal"

# Clean and create context
if (Test-Path $context) { Remove-Item -Recurse -Force $context }
New-Item -ItemType Directory $context | Out-Null

# Create minimal Dockerfile
@'
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y \
    libqt6core6t64 libqt6gui6t64 libqt6widgets6t64 \
    libqt6network6t64 libqt6qml6 libqt6quick6 \
    qml6-module-qtquick qml6-module-qtquick-controls \
    libgles2-mesa libegl1-mesa libasound2 libpulse0 \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY belt_control_system /app/
RUN chmod +x /app/belt_control_system
ENV QT_QPA_PLATFORM=eglfs
CMD ["/app/belt_control_system"]
'@ | Out-File -Encoding UTF8 "$context/Dockerfile"

# Copy binary
Copy-Item $binary "$context/"

# Build and deploy
Write-Host "Building Docker image..." -ForegroundColor Yellow
docker build -t belt-app:arm64 $context

Write-Host "Exporting image..." -ForegroundColor Yellow
docker save -o "$root/belt-app.tar" belt-app:arm64

Write-Host "Transferring to device..." -ForegroundColor Yellow
scp "$root/belt-app.tar" "pi@${Device}:/tmp/"

Write-Host "Deploying on device..." -ForegroundColor Yellow
ssh "pi@${Device}" @"
sudo docker load -i /tmp/belt-app.tar
sudo docker stop belt-control 2>/dev/null || true
sudo docker rm belt-control 2>/dev/null || true
sudo docker run -d --name belt-control --restart unless-stopped --privileged -v /dev:/dev belt-app:arm64
sudo docker ps | grep belt-control
rm /tmp/belt-app.tar
"@

# Cleanup
Remove-Item "$root/belt-app.tar" -ErrorAction SilentlyContinue
Remove-Item -Recurse $context -ErrorAction SilentlyContinue

Write-Host "`n[OK] Docker deployment complete!" -ForegroundColor Green
Write-Host "View logs: ssh pi@$Device 'sudo docker logs -f belt-control'" -ForegroundColor Cyan