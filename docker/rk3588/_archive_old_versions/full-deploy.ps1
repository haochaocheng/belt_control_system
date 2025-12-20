# Full Deployment Workflow
# Build image, save, transfer, load and run on remote

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RemoteHost = "192.168.10.170"
$RemoteUser = "pi"
$ImageFile = "$ScriptDir\belt-control-runtime.tar"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Full Docker Deployment Workflow" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Target: ${RemoteUser}@${RemoteHost}" -ForegroundColor Gray
Write-Host ""

# Phase 1: Build Docker image
Write-Host "Phase 1/5: Building Docker image..." -ForegroundColor Yellow
Write-Host ""
& "$ScriptDir\build-docker-image.ps1"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Image build failed" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Phase 2: Save image to tar
Write-Host ""
Write-Host "Phase 2/5: Saving image to file..." -ForegroundColor Yellow
if (Test-Path $ImageFile) {
    Remove-Item $ImageFile -Force
}

docker save belt-control-rk3588:runtime -o $ImageFile

if ($LASTEXITCODE -eq 0) {
    $fileSize = (Get-Item $ImageFile).Length / 1MB
    Write-Host "OK: Image saved (${fileSize:N2} MB)" -ForegroundColor Green
} else {
    Write-Host "ERROR: Failed to save image" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Phase 3: Transfer to remote
Write-Host ""
Write-Host "Phase 3/5: Transferring image to ${RemoteHost}..." -ForegroundColor Yellow
Write-Host "This may take several minutes..." -ForegroundColor Gray

scp $ImageFile ${RemoteUser}@${RemoteHost}:/tmp/belt-control-runtime.tar

if ($LASTEXITCODE -eq 0) {
    Write-Host "OK: Image transferred" -ForegroundColor Green
} else {
    Write-Host "ERROR: Transfer failed" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Phase 4: Load image on remote
Write-Host ""
Write-Host "Phase 4/5: Loading image on remote device..." -ForegroundColor Yellow

ssh ${RemoteUser}@${RemoteHost} "docker load -i /tmp/belt-control-runtime.tar"

if ($LASTEXITCODE -eq 0) {
    Write-Host "OK: Image loaded on remote" -ForegroundColor Green
} else {
    Write-Host "ERROR: Failed to load image" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

# Phase 5: Run container
Write-Host ""
Write-Host "Phase 5/5: Starting container..." -ForegroundColor Yellow

# Stop existing container if running
ssh ${RemoteUser}@${RemoteHost} "docker stop belt_control 2>/dev/null || true"
ssh ${RemoteUser}@${RemoteHost} "docker rm belt_control 2>/dev/null || true"

# Run new container
ssh ${RemoteUser}@${RemoteHost} @"
docker run -d \
    --name belt_control \
    --privileged \
    --network host \
    --restart unless-stopped \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -e DISPLAY=:0 \
    belt-control-rk3588:runtime
"@

if ($LASTEXITCODE -eq 0) {
    Write-Host "OK: Container started" -ForegroundColor Green
} else {
    Write-Host "WARNING: Container may have issues" -ForegroundColor Yellow
}

# Show container status
Write-Host ""
Write-Host "Checking container status..." -ForegroundColor Yellow
ssh ${RemoteUser}@${RemoteHost} "docker ps -a | grep belt_control"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Container name: belt_control" -ForegroundColor Cyan
Write-Host ""
Write-Host "Useful commands:" -ForegroundColor Yellow
Write-Host "  View logs:    ssh ${RemoteUser}@${RemoteHost} 'docker logs -f belt_control'" -ForegroundColor White
Write-Host "  Stop:         ssh ${RemoteUser}@${RemoteHost} 'docker stop belt_control'" -ForegroundColor White
Write-Host "  Start:        ssh ${RemoteUser}@${RemoteHost} 'docker start belt_control'" -ForegroundColor White
Write-Host "  Restart:      ssh ${RemoteUser}@${RemoteHost} 'docker restart belt_control'" -ForegroundColor White
Write-Host "  Status:       ssh ${RemoteUser}@${RemoteHost} 'docker ps | grep belt_control'" -ForegroundColor White
Write-Host ""

Read-Host "Press Enter to exit"
