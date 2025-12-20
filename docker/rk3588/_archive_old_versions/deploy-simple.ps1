# Simple Deploy - All operations on device
# Transfers source files and builds everything on the device

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$BuildRoot = "$ProjectRoot\build_rk3588_new"
$RK3588Libs = "$ScriptDir\rk3588-libs"
$RemoteHost = "192.168.10.170"
$RemoteUser = "pi"
$RemoteBuildDir = "/home/pi/belt-control-build"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Simple Deploy (All on Device)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Clean remote directory
Write-Host "Preparing remote directory..." -ForegroundColor Yellow
ssh ${RemoteUser}@${RemoteHost} "rm -rf $RemoteBuildDir && mkdir -p $RemoteBuildDir/libs"
Write-Host "  OK" -ForegroundColor Green
Write-Host ""

# Transfer binary
Write-Host "Transferring binary..." -ForegroundColor Yellow
scp "$BuildRoot\bin_arm64\belt_control_system" "${RemoteUser}@${RemoteHost}:$RemoteBuildDir/"
Write-Host "  OK" -ForegroundColor Green
Write-Host ""

# Transfer Dockerfile
Write-Host "Transferring Dockerfile..." -ForegroundColor Yellow
scp "$ScriptDir\Dockerfile.device" "${RemoteUser}@${RemoteHost}:$RemoteBuildDir/Dockerfile"
Write-Host "  OK" -ForegroundColor Green
Write-Host ""

# Transfer libraries (one by one to avoid symlink issues)
Write-Host "Transferring libraries (this may take a few minutes)..." -ForegroundColor Yellow
$libFiles = Get-ChildItem -Path "$RK3588Libs\lib" -File | Where-Object { $_.Extension -match "\.so" -or $_.Name -match "\.so\." }
$count = 0
foreach ($lib in $libFiles) {
    # Skip problematic symlinks
    if ($lib.Name -match "librknn_api|v4l1compat|v4l2convert") {
        continue
    }
    if (-not $lib.LinkType) {  # Only copy real files, not symlinks
        scp "$($lib.FullName)" "${RemoteUser}@${RemoteHost}:$RemoteBuildDir/libs/" 2>$null
        $count++
        if ($count % 20 -eq 0) {
            Write-Host "  Transferred $count files..." -ForegroundColor Gray
        }
    }
}
Write-Host "  OK Transferred $count library files" -ForegroundColor Green
Write-Host ""

# Build Docker image
Write-Host "Building Docker image on device (this may take 3-5 minutes)..." -ForegroundColor Yellow
ssh ${RemoteUser}@${RemoteHost} "cd $RemoteBuildDir && docker build -t belt-control-rk3588:runtime ."

if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK Docker image built" -ForegroundColor Green
} else {
    Write-Host "  ERROR Docker build failed" -ForegroundColor Red
    Write-Host ""
    Write-Host "To check the error, run:" -ForegroundColor Yellow
    Write-Host "  ssh ${RemoteUser}@${RemoteHost} 'cd $RemoteBuildDir && docker build -t belt-control-rk3588:runtime .'" -ForegroundColor White
    exit 1
}
Write-Host ""

# Start container
Write-Host "Starting container..." -ForegroundColor Yellow
ssh ${RemoteUser}@${RemoteHost} "docker stop belt_control 2>/dev/null || true && docker rm belt_control 2>/dev/null || true"
ssh ${RemoteUser}@${RemoteHost} "docker run -d --name belt_control --privileged --network host --restart unless-stopped -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=:0 belt-control-rk3588:runtime"

if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK Container started" -ForegroundColor Green
} else {
    Write-Host "  WARNING Container may have issues" -ForegroundColor Yellow
}
Write-Host ""

# Check status
Write-Host "Container status:" -ForegroundColor Yellow
ssh ${RemoteUser}@${RemoteHost} "docker ps | grep belt_control"

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "View logs: ssh ${RemoteUser}@${RemoteHost} 'docker logs -f belt_control'" -ForegroundColor Cyan
Write-Host ""
