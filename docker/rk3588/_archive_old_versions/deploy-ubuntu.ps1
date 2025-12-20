# Deploy to Ubuntu 20.04.6 LTS (192.168.10.155)
# User: linaro, Password: linaro

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$BuildRoot = "$ProjectRoot\build_rk3588_new"
$RK3588Libs = "$ScriptDir\rk3588-libs"

$RemoteHost = "192.168.10.155"
$RemoteUser = "linaro"
$RemoteBuildDir = "/home/linaro/belt-control-build"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deploy to Ubuntu 20.04.6 LTS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Target: ${RemoteUser}@${RemoteHost}" -ForegroundColor Gray
Write-Host ""

# Phase 1: Check SSH connection
Write-Host "Phase 1/5: Checking connection..." -ForegroundColor Yellow
ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ${RemoteUser}@${RemoteHost} "echo 'Connected'" 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK Connection established" -ForegroundColor Green
} else {
    Write-Host "  WARNING Cannot connect, you may need to enter password" -ForegroundColor Yellow
}
Write-Host ""

# Phase 2: Prepare remote directory
Write-Host "Phase 2/5: Preparing remote directory..." -ForegroundColor Yellow
ssh ${RemoteUser}@${RemoteHost} "rm -rf $RemoteBuildDir && mkdir -p $RemoteBuildDir/libs"
Write-Host "  OK Directory prepared" -ForegroundColor Green
Write-Host ""

# Phase 3: Transfer files
Write-Host "Phase 3/5: Transferring files..." -ForegroundColor Yellow

# Transfer binary
Write-Host "  Transferring binary..." -ForegroundColor Gray
scp "$BuildRoot\bin_arm64\belt_control_system" "${RemoteUser}@${RemoteHost}:$RemoteBuildDir/"
Write-Host "  OK Binary transferred" -ForegroundColor Green

# Transfer Dockerfile
Write-Host "  Transferring Dockerfile..." -ForegroundColor Gray
scp "$ScriptDir\Dockerfile.minimal" "${RemoteUser}@${RemoteHost}:$RemoteBuildDir/Dockerfile"
Write-Host "  OK Dockerfile transferred" -ForegroundColor Green

# Transfer libraries
Write-Host "  Transferring libraries..." -ForegroundColor Gray
$libFiles = Get-ChildItem -Path "$RK3588Libs\lib" -File | Where-Object { $_.Extension -match "\.so" -or $_.Name -match "\.so\." }
$count = 0
foreach ($lib in $libFiles) {
    if ($lib.Name -match "librknn_api|v4l1compat|v4l2convert") {
        continue
    }
    if (-not $lib.LinkType) {
        scp "$($lib.FullName)" "${RemoteUser}@${RemoteHost}:$RemoteBuildDir/libs/" 2>$null
        $count++
        if ($count % 20 -eq 0) {
            Write-Host "    Transferred $count files..." -ForegroundColor DarkGray
        }
    }
}
Write-Host "  OK Transferred $count library files" -ForegroundColor Green
Write-Host ""

# Phase 4: Check Docker
Write-Host "Phase 4/5: Checking Docker..." -ForegroundColor Yellow
$dockerVersion = ssh ${RemoteUser}@${RemoteHost} "docker --version 2>&1"
if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK $dockerVersion" -ForegroundColor Green
} else {
    Write-Host "  ERROR Docker not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Docker first:" -ForegroundColor Yellow
    Write-Host "  ssh ${RemoteUser}@${RemoteHost}" -ForegroundColor White
    Write-Host "  sudo apt-get update && sudo apt-get install -y docker.io" -ForegroundColor White
    Write-Host "  sudo usermod -aG docker linaro" -ForegroundColor White
    exit 1
}

# Check storage driver
$storageDriver = ssh ${RemoteUser}@${RemoteHost} "docker info 2>/dev/null | grep 'Storage Driver'"
Write-Host "  Storage: $storageDriver" -ForegroundColor Gray
Write-Host ""

# Phase 5: Transfer base image
Write-Host "Phase 5/5: Transferring Debian base image..." -ForegroundColor Yellow
Write-Host "  This may take 1-2 minutes..." -ForegroundColor Gray

# Check if tar file exists locally
$debianTarFile = "$ScriptDir\debian-bookworm-arm64.tar"
if (Test-Path $debianTarFile) {
    scp "$debianTarFile" "${RemoteUser}@${RemoteHost}:/tmp/"
    ssh ${RemoteUser}@${RemoteHost} "docker load -i /tmp/debian-bookworm-arm64.tar && docker tag arm64v8/debian:bookworm-slim debian:bookworm-slim"
    Write-Host "  OK Base image loaded" -ForegroundColor Green
} else {
    Write-Host "  Skipping (base image tar not found locally)" -ForegroundColor Yellow
    Write-Host "  Will pull from Docker Hub on device..." -ForegroundColor Gray
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "Files transferred successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Build Docker image:" -ForegroundColor White
Write-Host "     ssh ${RemoteUser}@${RemoteHost} 'cd $RemoteBuildDir && docker build -t belt-control-rk3588:runtime .'" -ForegroundColor Cyan
Write-Host ""
Write-Host "  2. Run container:" -ForegroundColor White
Write-Host "     ssh ${RemoteUser}@${RemoteHost} 'docker run -d --name belt_control --privileged --network host --restart unless-stopped -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=:0 belt-control-rk3588:runtime'" -ForegroundColor Cyan
Write-Host ""
Write-Host "  3. Check logs:" -ForegroundColor White
Write-Host "     ssh ${RemoteUser}@${RemoteHost} 'docker logs -f belt_control'" -ForegroundColor Cyan
Write-Host ""
