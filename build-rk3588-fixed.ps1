# RK3588 ARM64 Cross-Compilation Script - GLIBC Fix Version
param(
    [int]$Threads = 32,
    [switch]$CleanBuild = $false,
    [switch]$RebuildImage = $false
)

$ErrorActionPreference = "Stop"
$ProjectRoot = "e:/2025/3_gongkongji/belt_control_system"

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "RK3588 Cross-Compilation - GLIBC Fix v1.0" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Step 0: Check and build Docker image if needed
$dockerfilePath = "$ProjectRoot/docker/rk3588/Dockerfile.fixed"
$imageName = "belt-control-fixed:latest"
$imageExists = docker images -q $imageName 2>$null

if (-not $imageExists -or $RebuildImage) {
    Write-Host "Building fixed Docker image..." -ForegroundColor Yellow
    Write-Host "  This will install all required ARM64 libraries (about 500MB)" -ForegroundColor Gray
    Write-Host "  Estimated time: 5-10 minutes" -ForegroundColor Gray
    Write-Host ""

    # Build Docker image
    docker build -t $imageName -f $dockerfilePath "$ProjectRoot/docker/rk3588"

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker image build failed"
        exit 1
    }

    Write-Host "OK - Docker image built successfully" -ForegroundColor Green

    # Verify libraries are installed
    Write-Host ""
    Write-Host "Verifying ARM64 libraries..." -ForegroundColor Yellow
    docker run --rm $imageName /check-libs.sh
    Write-Host ""
} else {
    Write-Host "Using existing Docker image: $imageName" -ForegroundColor Green
}

# Step 1: Prepare build directory
$buildDir = "$ProjectRoot/build_rk3588"
if ($CleanBuild -and (Test-Path $buildDir)) {
    Write-Host "Cleaning build directory..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $buildDir
}
if (!(Test-Path $buildDir)) {
    New-Item -ItemType Directory $buildDir | Out-Null
}

Write-Host ""
Write-Host "Starting compilation..." -ForegroundColor Green
Write-Host "  Using container ARM64 libraries (GLIBC 2.39)" -ForegroundColor Gray
Write-Host "  Compilation threads: $Threads" -ForegroundColor Gray
Write-Host ""

# Step 2: Run compilation
# Skip EGL installation if it fails (paths are set in toolchain)
$installEglCmd = "if [ -f /tmp/install-egl-headers.sh ]; then /tmp/install-egl-headers.sh || echo 'EGL installation skipped (using toolchain paths)'; fi"
# Modified CMake command using new toolchain file
$cmakeCmd = "cmake -DCMAKE_TOOLCHAIN_FILE=/opt/qt-raspi/lib/cmake/Qt6/qt.toolchain.cmake -DQT_CHAINLOAD_TOOLCHAIN_FILE=/workspace/docker/rk3588/toolchain-fixed.cmake -DCMAKE_BUILD_TYPE=Release -DENABLE_SHERPA_ONNX=ON .."
$makeCmd = "make -j$Threads VERBOSE=1"
$fullCmd = "$installEglCmd && $cmakeCmd && $makeCmd"

# Run Docker container for compilation
# Mount rk3588-libs for PJSIP headers and libraries
docker run --rm `
    -v "${ProjectRoot}:/workspace" `
    -v "${ProjectRoot}/docker/rk3588/qt-host:/opt/qt-host:ro" `
    -v "${ProjectRoot}/docker/rk3588/qt-raspi:/opt/qt-raspi:ro" `
    -v "${ProjectRoot}/docker/rk3588/sysroot:/opt/sysroot:ro" `
    -v "${ProjectRoot}/docker/rk3588/rk3588-libs:/opt/rk3588-libs:ro" `
    -e QT_HOST_PATH=/opt/qt-host `
    -e QT_TARGET_PATH=/opt/qt-raspi `
    -e SYSROOT=/opt/sysroot/rk3588-root `
    -w /workspace/build_rk3588 `
    $imageName `
    bash -c "$fullCmd"

if ($LASTEXITCODE -eq 0) {
    $binary = "$buildDir/bin_arm64/belt_control_system"
    if (Test-Path $binary) {
        $size = (Get-Item $binary).Length / 1MB
        Write-Host ""
        Write-Host "===========================================" -ForegroundColor Green
        Write-Host "Compilation successful!" -ForegroundColor Green
        Write-Host "===========================================" -ForegroundColor Green
        Write-Host "Binary file: $binary" -ForegroundColor Gray
        Write-Host "File size: $([Math]::Round($size, 2)) MB" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Notes:" -ForegroundColor Cyan
        Write-Host "  - Using container ARM64 libraries (GLIBC 2.39)" -ForegroundColor White
        Write-Host "  - Fixed GLIBC version mismatch issue" -ForegroundColor White
        Write-Host "  - All dependency versions consistent" -ForegroundColor White
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "  1. Test binary linking dependencies:" -ForegroundColor White
        Write-Host "     docker run --rm -v `"${ProjectRoot}:/workspace`" $imageName ldd /workspace/build_rk3588/bin_arm64/belt_control_system" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  2. Deploy to device:" -ForegroundColor White
        Write-Host "     Continue with build-ubuntu24-apt.ps1 deployment steps" -ForegroundColor Gray
    } else {
        Write-Warning "Compilation completed but output file not found"
    }
} else {
    Write-Host ""
    Write-Error "Compilation failed - see error messages above"

    Write-Host ""
    Write-Host "Troubleshooting suggestions:" -ForegroundColor Yellow
    Write-Host "  1. Check if any libraries are still missing in error messages" -ForegroundColor White
    Write-Host "  2. Add missing libraries to Dockerfile.fixed if needed" -ForegroundColor White
    Write-Host "  3. Rebuild image: .\build-rk3588-fixed.ps1 -RebuildImage" -ForegroundColor White
    Write-Host ""
    exit 1
}