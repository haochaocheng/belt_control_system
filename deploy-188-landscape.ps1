# Deploy Belt Control System v3.3 to Device 188 (10-inch landscape)
# Uses X11 mode with xrandr rotation for landscape display

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Deploy to Device 188 - Landscape Mode" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$DeviceIP = "192.168.10.188"
$ImageFile = "e:\2025\3_gongkongji\belt_control_system\belt-control-production.tar"
$BinaryFile = "e:\2025\3_gongkongji\belt_control_system\build_rk3588\bin_arm64\belt_control_system"

# Check files
if (-not (Test-Path $ImageFile)) {
    Write-Host "ERROR: Image file not found" -ForegroundColor Red
    Write-Host "Please run export-production-image.ps1 first" -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $BinaryFile)) {
    Write-Host "ERROR: Binary file not found" -ForegroundColor Red
    Write-Host "Please run build-rk3588.ps1 first" -ForegroundColor Yellow
    exit 1
}

$imageSize = [math]::Round((Get-Item $ImageFile).Length / 1MB, 2)
Write-Host "Image file: $imageSize MB" -ForegroundColor Green
Write-Host "Binary file: Latest cross-compiled version" -ForegroundColor Green
Write-Host ""

Write-Host "Target device: $DeviceIP" -ForegroundColor Yellow
Write-Host "Display mode: X11 with landscape rotation (1280x800)" -ForegroundColor Yellow
Write-Host ""

$confirm = Read-Host "Continue deployment? (y/n)"
if ($confirm -ne "y") {
    Write-Host "Cancelled" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host "Step 1: Check connection..." -ForegroundColor Cyan
$result = ssh -o ConnectTimeout=5 linaro@$DeviceIP 'echo ok' 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Cannot connect to $DeviceIP" -ForegroundColor Red
    exit 1
}
Write-Host "  Connected" -ForegroundColor Green
Write-Host ""

Write-Host "Step 2: Check Docker..." -ForegroundColor Cyan
ssh linaro@$DeviceIP 'docker --version' 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Docker not found, installing..." -ForegroundColor Yellow
    ssh linaro@$DeviceIP 'sudo apt-get update && sudo apt-get install -y docker.io && sudo systemctl start docker && sudo systemctl enable docker && sudo usermod -aG docker linaro'
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  ERROR: Docker install failed" -ForegroundColor Red
        exit 1
    }
    Write-Host "  Please reconnect SSH session for docker group to take effect" -ForegroundColor Yellow
    exit 0
}
Write-Host "  Docker ready" -ForegroundColor Green
Write-Host ""

Write-Host "Step 3: Transfer production image ($imageSize MB)..." -ForegroundColor Cyan
Write-Host "  This may take a few minutes..." -ForegroundColor Gray
scp "$ImageFile" linaro@${DeviceIP}:/tmp/belt-control-production.tar
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Transfer failed" -ForegroundColor Red
    exit 1
}
Write-Host "  Transferred" -ForegroundColor Green
Write-Host ""

Write-Host "Step 4: Add user to docker group..." -ForegroundColor Cyan
ssh linaro@$DeviceIP 'sudo usermod -aG docker linaro'
Write-Host "  User added to docker group" -ForegroundColor Green
Write-Host ""

Write-Host "Step 5: Load production image..." -ForegroundColor Cyan
ssh linaro@$DeviceIP 'sudo docker load -i /tmp/belt-control-production.tar && rm /tmp/belt-control-production.tar'
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Load failed" -ForegroundColor Red
    exit 1
}
Write-Host "  Image loaded" -ForegroundColor Green
Write-Host ""

Write-Host "Step 6: Transfer updated binary with fullscreen fix..." -ForegroundColor Cyan
ssh linaro@$DeviceIP 'mkdir -p /home/linaro/belt-control-qt6'
scp "$BinaryFile" linaro@${DeviceIP}:/home/linaro/belt-control-qt6/belt_control_system
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Binary transfer failed" -ForegroundColor Red
    exit 1
}
Write-Host "  Binary transferred" -ForegroundColor Green
Write-Host ""

Write-Host "Step 7: Create updated Docker image..." -ForegroundColor Cyan
$dockerfile = @'
FROM belt-control:v3.3
RUN rm -f /app/belt_control_system
COPY belt_control_system /app/
RUN chmod +x /app/belt_control_system
'@
$dockerfile | ssh linaro@$DeviceIP 'cat > /home/linaro/belt-control-qt6/Dockerfile'

ssh linaro@$DeviceIP 'cd /home/linaro/belt-control-qt6 && sudo docker build -t belt-control:v3.3-fullscreen .'
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Docker build failed" -ForegroundColor Red
    exit 1
}
Write-Host "  Image built" -ForegroundColor Green
Write-Host ""

Write-Host "Step 8: Create run script..." -ForegroundColor Cyan
$runScript = @'
#!/bin/bash
# Belt Control System v3.3 - Device 188 (Landscape Mode)

sudo docker stop belt-control-app 2>/dev/null
sudo docker rm belt-control-app 2>/dev/null

echo "=========================================="
echo "Belt Control System v3.3 - Device 188"
echo "X11 Mode with Fullscreen Support"
echo "=========================================="
echo ""

# Grant X11 access
xhost +local:docker 2>/dev/null || echo "xhost not available, trying anyway..."

# Apply landscape rotation
DISPLAY=:0 xrandr --output DSI-1 --rotate left 2>/dev/null

echo "Starting application..."

sudo docker run \
    --name belt-control-app \
    --privileged \
    -e DISPLAY=:0 \
    -e QT_QPA_PLATFORM=xcb \
    -e XDG_RUNTIME_DIR=/tmp \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    -v /dev:/dev \
    -v /sys:/sys \
    -v /run/udev:/run/udev:ro \
    -v /usr/share/fonts:/usr/share/fonts:ro \
    belt-control:v3.3-fullscreen

EXIT_CODE=$?
echo ""
echo "Application exited with code: $EXIT_CODE"

if [ $EXIT_CODE -ne 0 ]; then
    echo ""
    echo "Last 30 lines of logs:"
    sudo docker logs --tail 30 belt-control-app
fi
'@
$runScript | ssh linaro@$DeviceIP 'cat > /home/linaro/run-188-landscape.sh && chmod +x /home/linaro/run-188-landscape.sh'
Write-Host "  Run script created: /home/linaro/run-188-landscape.sh" -ForegroundColor Green
Write-Host ""

Write-Host "==========================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "To run the application:" -ForegroundColor Yellow
Write-Host "  ssh linaro@$DeviceIP ./run-188-landscape.sh" -ForegroundColor White
Write-Host ""
Write-Host "Features:" -ForegroundColor Yellow
Write-Host "  - Auto-detect screen size (1280x800)" -ForegroundColor White
Write-Host "  - Fullscreen mode (no window decorations)" -ForegroundColor White
Write-Host "  - Landscape display (xrandr rotation)" -ForegroundColor White
Write-Host "  - Keyboard left/right arrow navigation" -ForegroundColor White
Write-Host ""
