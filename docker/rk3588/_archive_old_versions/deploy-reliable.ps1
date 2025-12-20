# Deploy on RK3588 Device - Reliable Version
# Uses tar.gz compression for faster and more reliable transfer

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$BuildRoot = "$ProjectRoot\build_rk3588_new"
$RK3588Libs = "$ScriptDir\rk3588-libs"
$RemoteHost = "192.168.10.170"
$RemoteUser = "pi"
$RemoteBuildDir = "/tmp/belt-control-build"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Deploy on RK3588 Device (Reliable)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Target: ${RemoteUser}@${RemoteHost}" -ForegroundColor Gray
Write-Host ""

# Phase 1: Prepare build files
Write-Host "Phase 1/5: Preparing build files..." -ForegroundColor Yellow

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

# Copy shared libraries (excluding problematic symlinks)
$allLibs = Get-ChildItem -Path "$RK3588Libs\lib" -Filter "*.so*" -File
foreach ($lib in $allLibs) {
    # Skip if it's a problematic symlink
    if ($lib.LinkType -eq "SymbolicLink") {
        $target = $lib.Target
        if ($target -and (Test-Path $target)) {
            # Copy the actual file, not the symlink
            Copy-Item $target "$LocalBuildDir\libs\$($lib.Name)" -Force
        }
    } else {
        Copy-Item $lib.FullName "$LocalBuildDir\libs\" -Force
    }
}
$libCount = (Get-ChildItem "$LocalBuildDir\libs" -File).Count
Write-Host "  OK $libCount shared libraries" -ForegroundColor Green

# Copy Dockerfile
Copy-Item "$ScriptDir\Dockerfile.device" "$LocalBuildDir\Dockerfile" -Force
Write-Host "  OK Dockerfile" -ForegroundColor Green

Write-Host ""

# Phase 2: Create compressed package
Write-Host "Phase 2/5: Creating compressed package..." -ForegroundColor Yellow

$packagePath = "$env:TEMP\belt-control-build.tar.gz"
if (Test-Path $packagePath) {
    Remove-Item $packagePath -Force
}

Push-Location $LocalBuildDir
& tar -czf $packagePath .
Pop-Location

if (Test-Path $packagePath) {
    $size = [math]::Round((Get-Item $packagePath).Length / 1MB, 2)
    Write-Host "  OK Package created ($size MB)" -ForegroundColor Green
} else {
    Write-Host "  ERROR Failed to create package" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Phase 3: Transfer to device
Write-Host "Phase 3/5: Transferring to device..." -ForegroundColor Yellow

# Clean remote directory
ssh ${RemoteUser}@${RemoteHost} "rm -rf $RemoteBuildDir && mkdir -p $RemoteBuildDir"

# Transfer package
scp $packagePath "${RemoteUser}@${RemoteHost}:/tmp/belt-control-build.tar.gz"

if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK Package transferred" -ForegroundColor Green
} else {
    Write-Host "  ERROR Transfer failed" -ForegroundColor Red
    Remove-Item $packagePath -Force -ErrorAction SilentlyContinue
    exit 1
}

# Extract on remote
Write-Host "  Extracting..." -ForegroundColor Gray
ssh ${RemoteUser}@${RemoteHost} "cd $RemoteBuildDir && tar -xzf /tmp/belt-control-build.tar.gz && rm /tmp/belt-control-build.tar.gz"

Write-Host "  OK Files extracted" -ForegroundColor Green
Write-Host ""

# Cleanup local package
Remove-Item $packagePath -Force -ErrorAction SilentlyContinue

# Phase 4: Build image on device
Write-Host "Phase 4/5: Building Docker image on device..." -ForegroundColor Yellow
Write-Host "  This may take 3-5 minutes..." -ForegroundColor Gray

ssh ${RemoteUser}@${RemoteHost} "cd $RemoteBuildDir && docker build -t belt-control-rk3588:runtime . && docker images | grep belt-control"

if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK Docker image built" -ForegroundColor Green
} else {
    Write-Host "  ERROR Docker build failed" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Phase 5: Start container
Write-Host "Phase 5/5: Starting container..." -ForegroundColor Yellow

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
