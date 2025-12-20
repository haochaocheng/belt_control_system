# Copy Docker image from 151 to 188
$ErrorActionPreference = "Stop"

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "Copy Docker Image: 151 -> 188" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

$Device151 = "linaro@192.168.10.151"
$Device188 = "linaro@192.168.10.188"
$ImageName = "belt-control:v3.3"
$TempFile = "/tmp/belt-control-from-151.tar"

# Step 1: Export image from 151
Write-Host "Step 1: Exporting image from 151..." -ForegroundColor Cyan
ssh $Device151 "docker save $ImageName -o $TempFile"
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Failed to export image" -ForegroundColor Red
    exit 1
}

$imageSize = (ssh $Device151 "du -h $TempFile | cut -f1").Trim()
Write-Host "  Exported: $imageSize" -ForegroundColor Green
Write-Host ""

# Step 2: Transfer to 188
Write-Host "Step 2: Transferring to 188..." -ForegroundColor Cyan
Write-Host "  This may take several minutes (1.7GB)..." -ForegroundColor Yellow
ssh $Device151 "cat $TempFile" | ssh $Device188 "cat > $TempFile"
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Transfer failed" -ForegroundColor Red
    exit 1
}
Write-Host "  Transfer complete" -ForegroundColor Green
Write-Host ""

# Step 3: Load on 188
Write-Host "Step 3: Loading image on 188..." -ForegroundColor Cyan
ssh $Device188 "docker load -i $TempFile && rm $TempFile"
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Load failed" -ForegroundColor Red
    exit 1
}
Write-Host "  Image loaded" -ForegroundColor Green
Write-Host ""

# Step 4: Cleanup 151
Write-Host "Step 4: Cleanup..." -ForegroundColor Cyan
ssh $Device151 "rm $TempFile"
Write-Host "  Cleaned up" -ForegroundColor Green
Write-Host ""

# Step 5: Create run script on 188
Write-Host "Step 5: Creating run script on 188..." -ForegroundColor Cyan
$runScript = @'
#!/bin/bash
# Belt Control System v3.3 - Device 188 (from 151)

sudo docker stop belt-control-app 2>/dev/null
sudo docker rm belt-control-app 2>/dev/null

echo "=========================================="
echo "Belt Control System v3.3 - Device 188"
echo "Image from 151"
echo "=========================================="
echo ""

xhost +local:docker 2>/dev/null || echo "xhost not available, trying anyway..."

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
    belt-control:v3.3

EXIT_CODE=$?
echo ""
echo "Application exited with code: $EXIT_CODE"

if [ $EXIT_CODE -ne 0 ]; then
    echo ""
    echo "Last 30 lines of logs:"
    sudo docker logs --tail 30 belt-control-app
fi
'@

$runScript | ssh $Device188 'cat > /home/linaro/run-188-from-151.sh && chmod +x /home/linaro/run-188-from-151.sh'
Write-Host "  Run script created: /home/linaro/run-188-from-151.sh" -ForegroundColor Green
Write-Host ""

Write-Host "===========================================" -ForegroundColor Green
Write-Host "Copy Complete!" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green
Write-Host ""
Write-Host "To run the application on 188:" -ForegroundColor Yellow
Write-Host "  ssh $Device188 ./run-188-from-151.sh" -ForegroundColor White
Write-Host ""
