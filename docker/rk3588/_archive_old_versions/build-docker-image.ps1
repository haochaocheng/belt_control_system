# Build Docker Image
# Complete workflow: prepare files and build image

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DockerBuildDir = "$ScriptDir\docker-build"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Building Docker Image" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Prepare files
Write-Host "Phase 1: Preparing build files..." -ForegroundColor Yellow
Write-Host ""

try {
    & "$ScriptDir\prepare-docker-build.ps1"
    if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw "Preparation script failed"
    }
} catch {
    Write-Host "ERROR: Failed to prepare build files - $_" -ForegroundColor Red
    exit 1
}

# Step 2: Build Docker image
Write-Host "Phase 2: Building Docker image..." -ForegroundColor Yellow
Write-Host ""

Push-Location $DockerBuildDir
try {
    docker build -t belt-control-rk3588:runtime .

    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Docker image built successfully!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Image name: belt-control-rk3588:runtime" -ForegroundColor Cyan
        Write-Host ""

        # Show image info
        Write-Host "Image details:" -ForegroundColor Yellow
        docker images belt-control-rk3588:runtime
        Write-Host ""

        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "  1. Save image: docker save belt-control-rk3588:runtime -o belt-control-runtime.tar" -ForegroundColor White
        Write-Host "  2. Transfer to device: scp belt-control-runtime.tar pi@192.168.10.170:/tmp/" -ForegroundColor White
        Write-Host "  3. Load on device: ssh pi@192.168.10.170 'docker load -i /tmp/belt-control-runtime.tar'" -ForegroundColor White
        Write-Host "  4. Run container: ssh pi@192.168.10.170 'docker run -d --privileged belt-control-rk3588:runtime'" -ForegroundColor White
        Write-Host ""

    } else {
        Write-Host ""
        Write-Host "ERROR: Docker build failed" -ForegroundColor Red
        exit 1
    }
} finally {
    Pop-Location
}
