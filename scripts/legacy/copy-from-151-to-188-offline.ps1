# Copy Docker image from 151 to 188 (Offline method via local disk)
$ErrorActionPreference = "Stop"

Write-Host "===========================================`n" -ForegroundColor Cyan
Write-Host "Copy Docker Image: 151 -> Local -> 188" -ForegroundColor Cyan
Write-Host "===========================================`n" -ForegroundColor Cyan

$Device151 = "linaro@192.168.10.151"
$Device188 = "linaro@192.168.10.188"
$ImageName = "belt-control:v3.3"
$RemoteTempFile = "/tmp/belt-control-from-151.tar"
$LocalTempFile = "e:\2025\3_gongkongji\belt-control-from-151.tar"

# Step 1: Export image from 151
Write-Host "Step 1: Exporting image from 151..." -ForegroundColor Cyan
ssh $Device151 "docker save $ImageName -o $RemoteTempFile"
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Failed to export image" -ForegroundColor Red
    exit 1
}

$imageSize = (ssh $Device151 "du -h $RemoteTempFile | cut -f1").Trim()
Write-Host "  Exported: $imageSize`n" -ForegroundColor Green

# Step 2: Download to local machine
Write-Host "Step 2: Downloading to local machine..." -ForegroundColor Cyan
Write-Host "  Target: $LocalTempFile" -ForegroundColor White
Write-Host "  This may take several minutes (1.7GB)..." -ForegroundColor Yellow

# Remove old local file if exists
if (Test-Path $LocalTempFile) {
    Write-Host "  Removing old local file..." -ForegroundColor Gray
    Remove-Item $LocalTempFile -Force
}

scp "${Device151}:${RemoteTempFile}" $LocalTempFile
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Download failed" -ForegroundColor Red
    ssh $Device151 "rm $RemoteTempFile"
    exit 1
}

$localSize = [math]::Round((Get-Item $LocalTempFile).Length / 1GB, 2)
Write-Host "  Downloaded: ${localSize}GB`n" -ForegroundColor Green

# Step 3: Cleanup 151
Write-Host "Step 3: Cleanup 151..." -ForegroundColor Cyan
ssh $Device151 "rm $RemoteTempFile"
Write-Host "  Cleaned up`n" -ForegroundColor Green

# Step 4: Upload to 188
Write-Host "Step 4: Uploading to 188..." -ForegroundColor Cyan
Write-Host "  This may take several minutes (1.7GB)..." -ForegroundColor Yellow

scp $LocalTempFile "${Device188}:${RemoteTempFile}"
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Upload failed" -ForegroundColor Red
    Write-Host "  Local file kept at: $LocalTempFile" -ForegroundColor Yellow
    exit 1
}
Write-Host "  Upload complete`n" -ForegroundColor Green

# Step 5: Load on 188
Write-Host "Step 5: Loading image on 188..." -ForegroundColor Cyan
ssh $Device188 "docker load -i $RemoteTempFile && rm $RemoteTempFile"
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Load failed" -ForegroundColor Red
    Write-Host "  Local file kept at: $LocalTempFile" -ForegroundColor Yellow
    exit 1
}
Write-Host "  Image loaded`n" -ForegroundColor Green

# Step 6: Create run script on 188
Write-Host "Step 6: Creating run script on 188..." -ForegroundColor Cyan
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
Write-Host "  Run script created: /home/linaro/run-188-from-151.sh`n" -ForegroundColor Green

# Step 7: Cleanup local file (optional)
Write-Host "Step 7: Cleanup local file..." -ForegroundColor Cyan
Write-Host "  Local file: $LocalTempFile (${localSize}GB)" -ForegroundColor White
$cleanup = Read-Host "  Delete local file? (y/N)"
if ($cleanup -eq "y" -or $cleanup -eq "Y") {
    Remove-Item $LocalTempFile -Force
    Write-Host "  Local file deleted`n" -ForegroundColor Green
} else {
    Write-Host "  Local file kept for backup`n" -ForegroundColor Yellow
}

Write-Host "===========================================`n" -ForegroundColor Green
Write-Host "Copy Complete!" -ForegroundColor Green
Write-Host "===========================================`n" -ForegroundColor Green
Write-Host "To run the application on 188:" -ForegroundColor Yellow
Write-Host "  ssh $Device188 ./run-188-from-151.sh`n" -ForegroundColor White
