# Deploy Directly on RK3588 Device
# Build Docker image directly on the device to avoid registry issues

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$BuildRoot = "$ProjectRoot\build_rk3588_new"
$RK3588Libs = "$ScriptDir\rk3588-libs"
$RemoteHost = "192.168.10.170"
$RemoteUser = "pi"
$RemoteBuildDir = "/tmp/belt-control-build"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deploy on RK3588 Device" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Target: ${RemoteUser}@${RemoteHost}" -ForegroundColor Gray
Write-Host ""

# Phase 1: Prepare build files
Write-Host "Phase 1/4: Preparing build files..." -ForegroundColor Yellow

$LocalBuildDir = "$ScriptDir\device-build"
if (Test-Path $LocalBuildDir) {
    Remove-Item -Recurse -Force $LocalBuildDir
}
New-Item -ItemType Directory -Path $LocalBuildDir | Out-Null
New-Item -ItemType Directory -Path "$LocalBuildDir\libs" | Out-Null

# Copy binary
$binaryPath = "$BuildRoot\bin_arm64\belt_control_system"
Copy-Item $binaryPath "$LocalBuildDir\" -Force
Write-Host "  OK Binary" -ForegroundColor Green

# Copy shared libraries
$sherpaLibs = Get-ChildItem -Path "$RK3588Libs\lib" -Filter "libsherpa-onnx*.so*"
foreach ($lib in $sherpaLibs) {
    Copy-Item $lib.FullName "$LocalBuildDir\libs\" -Force
}
$onnxLibs = Get-ChildItem -Path "$RK3588Libs\lib" -Filter "libonnxruntime*.so*"
foreach ($lib in $onnxLibs) {
    Copy-Item $lib.FullName "$LocalBuildDir\libs\" -Force
}
$rknnLibs = Get-ChildItem -Path "$RK3588Libs\lib" -Filter "librknn*.so*"
foreach ($lib in $rknnLibs) {
    Copy-Item $lib.FullName "$LocalBuildDir\libs\" -Force
}
$otherLibs = Get-ChildItem -Path "$RK3588Libs\lib" -Filter "*.so*" |
    Where-Object { $_.Name -notlike "libsherpa*" -and $_.Name -notlike "libonnx*" -and $_.Name -notlike "librknn*" }
foreach ($lib in $otherLibs) {
    Copy-Item $lib.FullName "$LocalBuildDir\libs\" -Force
}
$libCount = (Get-ChildItem "$LocalBuildDir\libs" -File).Count
Write-Host "  OK $libCount shared libraries" -ForegroundColor Green

# Copy Dockerfile
Copy-Item "$ScriptDir\Dockerfile.device" "$LocalBuildDir\Dockerfile" -Force
Write-Host "  OK Dockerfile" -ForegroundColor Green

Write-Host ""

# Phase 2: Transfer to device
Write-Host "Phase 2/4: Transferring to device..." -ForegroundColor Yellow

# Clean remote directory
ssh ${RemoteUser}@${RemoteHost} "rm -rf $RemoteBuildDir && mkdir -p $RemoteBuildDir"

# Create tar archive and transfer via pipe
Write-Host "  Creating and transferring package..." -ForegroundColor Gray
Push-Location $LocalBuildDir
$tarCmd = "tar -cf - . | ssh ${RemoteUser}@${RemoteHost} `"cd $RemoteBuildDir && tar -xf -`""
Invoke-Expression $tarCmd
Pop-Location

if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK Files transferred" -ForegroundColor Green
} else {
    Write-Host "  ERROR Transfer failed" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Phase 3: Build image on device
Write-Host "Phase 3/4: Building Docker image on device..." -ForegroundColor Yellow
Write-Host "  This may take 3-5 minutes..." -ForegroundColor Gray

ssh ${RemoteUser}@${RemoteHost} "cd $RemoteBuildDir && docker build -t belt-control-rk3588:runtime . && docker images | grep belt-control"

if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK Docker image built" -ForegroundColor Green
} else {
    Write-Host "  ERROR Docker build failed" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Phase 4: Start container
Write-Host "Phase 4/4: Starting container..." -ForegroundColor Yellow

# Stop old container
ssh ${RemoteUser}@${RemoteHost} "docker stop belt_control 2>/dev/null || true"
ssh ${RemoteUser}@${RemoteHost} "docker rm belt_control 2>/dev/null || true"
Write-Host "  OK Cleanup old container" -ForegroundColor Green

# Start new container
ssh ${RemoteUser}@${RemoteHost} "docker run -d --name belt_control --privileged --network host --restart unless-stopped -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=:0 belt-control-rk3588:runtime"

if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK Container started" -ForegroundColor Green
} else {
    Write-Host "  WARNING Container may have issues" -ForegroundColor Yellow
}

Write-Host ""

# Check container status
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
Write-Host "  View logs:  ssh ${RemoteUser}@${RemoteHost} 'docker logs -f belt_control'" -ForegroundColor White
Write-Host "  Stop:       ssh ${RemoteUser}@${RemoteHost} 'docker stop belt_control'" -ForegroundColor White
Write-Host "  Start:      ssh ${RemoteUser}@${RemoteHost} 'docker start belt_control'" -ForegroundColor White
Write-Host "  Restart:    ssh ${RemoteUser}@${RemoteHost} 'docker restart belt_control'" -ForegroundColor White
Write-Host "  Status:     ssh ${RemoteUser}@${RemoteHost} 'docker ps | grep belt_control'" -ForegroundColor White
Write-Host ""

# Cleanup local files
Remove-Item -Recurse -Force $LocalBuildDir -ErrorAction SilentlyContinue

Write-Host "Done! Container is running on device." -ForegroundColor Green
Write-Host ""
