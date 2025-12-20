# Final Ubuntu Deploy Script - With working SSH keys
# Target: Ubuntu 20.04.6 LTS (192.168.10.155)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$BuildRoot = "$ProjectRoot\build_rk3588_new"
$RK3588Libs = "$ScriptDir\rk3588-libs"

$RemoteHost = "192.168.10.155"
$RemoteUser = "linaro"
$RemoteBuildDir = "/home/linaro/belt-control-build"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deploy to Ubuntu 20.04.6 LTS (aarch64)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Phase 1: Prepare remote directory
Write-Host "Phase 1/4: Preparing remote directory..." -ForegroundColor Yellow
ssh ${RemoteUser}@${RemoteHost} "rm -rf $RemoteBuildDir && mkdir -p $RemoteBuildDir/libs"
Write-Host "  OK" -ForegroundColor Green
Write-Host ""

# Phase 2: Transfer binary
Write-Host "Phase 2/4: Transferring binary..." -ForegroundColor Yellow
scp "$BuildRoot\bin_arm64\belt_control_system" "${RemoteUser}@${RemoteHost}:$RemoteBuildDir/"
Write-Host "  OK" -ForegroundColor Green
Write-Host ""

# Phase 3: Transfer Dockerfile
Write-Host "Phase 3/4: Transferring Dockerfile..." -ForegroundColor Yellow
scp "$ScriptDir\Dockerfile.minimal" "${RemoteUser}@${RemoteHost}:$RemoteBuildDir/Dockerfile"
Write-Host "  OK" -ForegroundColor Green
Write-Host ""

# Phase 4: Transfer libraries (one by one)
Write-Host "Phase 4/4: Transferring libraries..." -ForegroundColor Yellow
Write-Host "  This will take 2-3 minutes..." -ForegroundColor Gray

$libFiles = Get-ChildItem -Path "$RK3588Libs\lib" -File | Where-Object {
    ($_.Extension -match "\.so" -or $_.Name -match "\.so\.") -and
    ($_.Name -notmatch "librknn_api|v4l1compat|v4l2convert") -and
    (-not $_.LinkType)
}

$count = 0
foreach ($lib in $libFiles) {
    scp "$($lib.FullName)" "${RemoteUser}@${RemoteHost}:$RemoteBuildDir/libs/" 2>$null
    $count++
    if ($count % 20 -eq 0) {
        Write-Host "    Transferred $count/$($libFiles.Count) files..." -ForegroundColor DarkGray
    }
}
Write-Host "  OK Transferred $count library files" -ForegroundColor Green
Write-Host ""

# Verify files on device
Write-Host "Verifying files on device..." -ForegroundColor Yellow
ssh ${RemoteUser}@${RemoteHost} "cd $RemoteBuildDir && ls -lh | head -5 && echo '---' && ls libs/ | wc -l"
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "Files transferred successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next: Build and run Docker container" -ForegroundColor Yellow
Write-Host ""
Write-Host "Option 1: Automatic (run now):" -ForegroundColor Cyan
Write-Host "  Execute the following commands automatically" -ForegroundColor Gray
Write-Host ""
Write-Host "Option 2: Manual:" -ForegroundColor Cyan
Write-Host "  ssh linaro@192.168.10.155" -ForegroundColor White
Write-Host "  cd /home/linaro/belt-control-build" -ForegroundColor White
Write-Host "  docker build -t belt-control:latest ." -ForegroundColor White
Write-Host "  docker run -d --name belt_control --privileged --network host --restart unless-stopped belt-control:latest" -ForegroundColor White
Write-Host "  docker logs -f belt_control" -ForegroundColor White
Write-Host ""

$choice = Read-Host "Do you want to build and run Docker now? (y/n)"
if ($choice -eq 'y' -or $choice -eq 'Y') {
    Write-Host ""
    Write-Host "Building Docker image..." -ForegroundColor Yellow
    ssh ${RemoteUser}@${RemoteHost} "cd $RemoteBuildDir && docker build -t belt-control:latest ."

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Starting container..." -ForegroundColor Yellow
        ssh ${RemoteUser}@${RemoteHost} @"
            docker stop belt_control 2>/dev/null || true &&
            docker rm belt_control 2>/dev/null || true &&
            docker run -d --name belt_control --privileged --network host --restart unless-stopped \
                -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=:0 \
                belt-control:latest
"@

        if ($LASTEXITCODE -eq 0) {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Green
            Write-Host "Deployment Complete!" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Green
            Write-Host ""
            Write-Host "Container is running. Checking status..." -ForegroundColor Yellow
            Start-Sleep -Seconds 2
            ssh ${RemoteUser}@${RemoteHost} "docker ps | grep belt_control"
            Write-Host ""
            Write-Host "View logs with:" -ForegroundColor Cyan
            Write-Host "  ssh linaro@192.168.10.155 'docker logs -f belt_control'" -ForegroundColor White
        } else {
            Write-Host "Container start failed" -ForegroundColor Red
        }
    } else {
        Write-Host "Docker build failed" -ForegroundColor Red
    }
}

Write-Host ""
