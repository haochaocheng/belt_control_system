# RK3588 ARM64 Cross-Compilation Script - Without SIP/PJSIP
param(
    [int]$Threads = 32,
    [switch]$CleanBuild = $false
)

$ErrorActionPreference = "Stop"
$ProjectRoot = "e:/2025/3_gongkongji/belt_control_system"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "RK3588 Cross-Compilation (No SIP)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check Docker image
$imageName = "belt-control-fixed:latest"
$imageExists = docker images -q $imageName 2>$null

if (-not $imageExists) {
    Write-Error "Docker image not found. Please run build-rk3588-fixed.ps1 first"
    exit 1
}

# Prepare build directory
$buildDir = "$ProjectRoot/build_rk3588"
if ($CleanBuild -and (Test-Path $buildDir)) {
    Write-Host "Cleaning build directory..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $buildDir
}
if (!(Test-Path $buildDir)) {
    New-Item -ItemType Directory $buildDir | Out-Null
}

Write-Host "Starting compilation without SIP..." -ForegroundColor Green
Write-Host "  Compilation threads: $Threads" -ForegroundColor Gray
Write-Host ""

# CMake command with SIP disabled
$cmakeCmd = "cmake -DCMAKE_TOOLCHAIN_FILE=/opt/qt-raspi/lib/cmake/Qt6/qt.toolchain.cmake -DQT_CHAINLOAD_TOOLCHAIN_FILE=/workspace/docker/rk3588/toolchain-fixed.cmake -DCMAKE_BUILD_TYPE=Release -DENABLE_SHERPA_ONNX=ON -DENABLE_SIP_PHONE=OFF .."
$makeCmd = "make -j$Threads"
$fullCmd = "$cmakeCmd && $makeCmd"

# Run Docker container
docker run --rm `
    -v "${ProjectRoot}:/workspace" `
    -v "${ProjectRoot}/docker/rk3588/qt-host:/opt/qt-host:ro" `
    -v "${ProjectRoot}/docker/rk3588/qt-raspi:/opt/qt-raspi:ro" `
    -v "${ProjectRoot}/docker/rk3588/sysroot:/opt/sysroot:ro" `
    -e QT_HOST_PATH=/opt/qt-host `
    -e QT_TARGET_PATH=/opt/qt-raspi `
    -e SYSROOT=/opt/sysroot/pi-root `
    -w /workspace/build_rk3588 `
    $imageName `
    bash -c "$fullCmd"

if ($LASTEXITCODE -eq 0) {
    $binary = "$buildDir/bin_arm64/belt_control_system"
    if (Test-Path $binary) {
        $size = (Get-Item $binary).Length / 1MB
        Write-Host ""
        Write-Host "==========================================" -ForegroundColor Green
        Write-Host "Compilation successful!" -ForegroundColor Green
        Write-Host "==========================================" -ForegroundColor Green
        Write-Host "Binary: $binary" -ForegroundColor Gray
        Write-Host "Size: $([Math]::Round($size, 2)) MB" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Note: SIP phone functionality disabled" -ForegroundColor Yellow
    } else {
        Write-Warning "Compilation completed but output file not found"
    }
} else {
    Write-Error "Compilation failed"
    exit 1
}