# Prepare Docker Build Files
# This script prepares all files needed for Docker build

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$BuildRoot = "$ProjectRoot\build_rk3588_new"
$RK3588Libs = "$ScriptDir\rk3588-libs"
$DockerBuildDir = "$ScriptDir\docker-build"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Preparing Docker Build" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Create build directory
Write-Host "Step 1: Creating build directory..." -ForegroundColor Yellow
if (Test-Path $DockerBuildDir) {
    Remove-Item -Recurse -Force $DockerBuildDir
}
New-Item -ItemType Directory -Path $DockerBuildDir | Out-Null
New-Item -ItemType Directory -Path "$DockerBuildDir\libs" | Out-Null
Write-Host "OK: Build directory created" -ForegroundColor Green
Write-Host ""

# Step 2: Copy binary
Write-Host "Step 2: Copying binary..." -ForegroundColor Yellow
$binaryPath = "$BuildRoot\bin_arm64\belt_control_system"
if (-not (Test-Path $binaryPath)) {
    Write-Host "ERROR: Binary not found at $binaryPath" -ForegroundColor Red
    exit 1
}
Copy-Item $binaryPath "$DockerBuildDir\" -Force
Write-Host "OK: Binary copied" -ForegroundColor Green
Write-Host ""

# Step 3: Copy PJSIP libraries
Write-Host "Step 3: Copying PJSIP libraries..." -ForegroundColor Yellow
$pjsipLibs = @(
    "libpjsua-aarch64-unknown-linux-gnu.a",
    "libpjsua2-aarch64-unknown-linux-gnu.a",
    "libpjsip-aarch64-unknown-linux-gnu.a",
    "libpjsip-simple-aarch64-unknown-linux-gnu.a",
    "libpjsip-ua-aarch64-unknown-linux-gnu.a",
    "libpjmedia-aarch64-unknown-linux-gnu.a",
    "libpjmedia-codec-aarch64-unknown-linux-gnu.a",
    "libpjmedia-videodev-aarch64-unknown-linux-gnu.a",
    "libpjmedia-audiodev-aarch64-unknown-linux-gnu.a",
    "libpjnath-aarch64-unknown-linux-gnu.a",
    "libpjlib-util-aarch64-unknown-linux-gnu.a",
    "libpj-aarch64-unknown-linux-gnu.a"
)

$pjsipCount = 0
foreach ($lib in $pjsipLibs) {
    $sourcePath = "$RK3588Libs\lib\$lib"
    if (Test-Path $sourcePath) {
        # Note: Static libraries (.a) don't need to be copied to runtime
        $pjsipCount++
    }
}
Write-Host "OK: Found $pjsipCount PJSIP libraries (static, linked in binary)" -ForegroundColor Green
Write-Host ""

# Step 4: Copy Sherpa-ONNX libraries
Write-Host "Step 4: Copying Sherpa-ONNX libraries..." -ForegroundColor Yellow
$sherpaLibs = Get-ChildItem -Path "$RK3588Libs\lib" -Filter "libsherpa-onnx*.so*" -ErrorAction SilentlyContinue
foreach ($lib in $sherpaLibs) {
    Copy-Item $lib.FullName "$DockerBuildDir\libs\" -Force
    Write-Host "  Copied: $($lib.Name)" -ForegroundColor Gray
}

$onnxLibs = Get-ChildItem -Path "$RK3588Libs\lib" -Filter "libonnxruntime*.so*" -ErrorAction SilentlyContinue
foreach ($lib in $onnxLibs) {
    Copy-Item $lib.FullName "$DockerBuildDir\libs\" -Force
    Write-Host "  Copied: $($lib.Name)" -ForegroundColor Gray
}

$rknnLibs = Get-ChildItem -Path "$RK3588Libs\lib" -Filter "librknn*.so*" -ErrorAction SilentlyContinue
foreach ($lib in $rknnLibs) {
    Copy-Item $lib.FullName "$DockerBuildDir\libs\" -Force
    Write-Host "  Copied: $($lib.Name)" -ForegroundColor Gray
}

Write-Host "OK: Sherpa-ONNX libraries copied" -ForegroundColor Green
Write-Host ""

# Step 5: Copy other required .so libraries
Write-Host "Step 5: Copying other shared libraries..." -ForegroundColor Yellow
$otherLibs = Get-ChildItem -Path "$RK3588Libs\lib" -Filter "*.so*" -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notlike "libsherpa*" -and $_.Name -notlike "libonnx*" -and $_.Name -notlike "librknn*" -and $_.Name -notlike "*.a" }

foreach ($lib in $otherLibs) {
    Copy-Item $lib.FullName "$DockerBuildDir\libs\" -Force -ErrorAction SilentlyContinue
    Write-Host "  Copied: $($lib.Name)" -ForegroundColor Gray
}
Write-Host "OK: Additional libraries copied" -ForegroundColor Green
Write-Host ""

# Step 6: Copy Dockerfile
Write-Host "Step 6: Copying Dockerfile..." -ForegroundColor Yellow
Copy-Item "$ScriptDir\Dockerfile.simple" "$DockerBuildDir\Dockerfile" -Force
Write-Host "OK: Dockerfile copied" -ForegroundColor Green
Write-Host ""

# Step 7: List build contents
Write-Host "Step 7: Verifying build contents..." -ForegroundColor Yellow
$binarySize = [math]::Round((Get-Item "$DockerBuildDir\belt_control_system").Length / 1MB, 2)
$libCount = (Get-ChildItem "$DockerBuildDir\libs" -File).Count
$libSizeBytes = (Get-ChildItem "$DockerBuildDir\libs" -File | Measure-Object -Property Length -Sum).Sum
$libSize = if ($libSizeBytes) { [math]::Round($libSizeBytes / 1MB, 2) } else { 0 }
$totalSize = [math]::Round($binarySize + $libSize, 2)

Write-Host "  Binary: belt_control_system ($binarySize MB)" -ForegroundColor Gray
Write-Host "  Libraries: $libCount files ($libSize MB)" -ForegroundColor Gray
Write-Host "  Total: $totalSize MB" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "Build preparation complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Build directory: $DockerBuildDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next step:" -ForegroundColor Yellow
Write-Host "  cd $DockerBuildDir" -ForegroundColor White
Write-Host "  docker build -t belt-control-rk3588:runtime ." -ForegroundColor White
Write-Host ""

exit 0
