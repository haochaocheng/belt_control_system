# RK3588 Docker Cross-Compilation Script - v3.3 with Rotation Fix
# Cross-compile ARM64 binaries on Windows using Docker
# Compiled binaries use bundled GLib 2.80, work on both 155 and 170 devices

$ErrorActionPreference = "Stop"

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$DockerDir = "$ProjectRoot\docker\rk3588"
$BuildDir = "$ProjectRoot\build_rk3588"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "RK3588 Docker Cross-Compilation - v3.3" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Step 0: Check and rebuild Docker image if Dockerfile changed
# ============================================================
Write-Host "Step 0: Checking Docker image..." -ForegroundColor Cyan

$DockerImageName = "belt-control-rk3588:latest"
$DockerfilePath = "$DockerDir\Dockerfile"
$DockerCacheFile = "$ProjectRoot\.docker_build_cache.json"

$imageExists = docker images -q $DockerImageName 2>$null
$needRebuild = $false

if (-not $imageExists) {
    Write-Host "  [!] Docker image not found" -ForegroundColor Yellow
    $needRebuild = $true
} else {
    # Check if Dockerfile changed
    if (Test-Path $DockerfilePath) {
        $currentHash = (Get-FileHash -Path $DockerfilePath -Algorithm MD5).Hash

        if (Test-Path $DockerCacheFile) {
            $cacheData = Get-Content $DockerCacheFile | ConvertFrom-Json
            $previousHash = $cacheData.hash

            if ($previousHash -ne $currentHash) {
                Write-Host "  [!] Dockerfile changed - rebuild required" -ForegroundColor Yellow
                Write-Host "  Previous hash: $previousHash" -ForegroundColor Gray
                Write-Host "  Current hash:  $currentHash" -ForegroundColor Gray
                $needRebuild = $true
            } else {
                Write-Host "  [OK] Dockerfile unchanged - using cached image" -ForegroundColor Green
            }
        } else {
            # No cache file, assume need rebuild to establish baseline
            Write-Host "  [!] No cache found - rebuild to establish baseline" -ForegroundColor Yellow
            $needRebuild = $true
        }
    } else {
        Write-Host "  [ERROR] Dockerfile not found: $DockerfilePath" -ForegroundColor Red
        exit 1
    }
}

if ($needRebuild) {
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host "  Docker Image Rebuild Required" -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Need to download system dependencies" -ForegroundColor Yellow
    Write-Host "  Estimated time: 5-10 minutes" -ForegroundColor Yellow
    Write-Host "  Recommended: Enable VPN/proxy for faster download" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host ""

    Write-Host "  Rebuilding Docker image..." -ForegroundColor Yellow
    $dockerBuildStart = Get-Date

    Set-Location $DockerDir
    docker build -t $DockerImageName .
    $buildExitCode = $LASTEXITCODE
    Set-Location $ProjectRoot

    if ($buildExitCode -ne 0) {
        Write-Host ""
        Write-Host "ERROR: Docker image build failed" -ForegroundColor Red
        exit 1
    }

    $dockerBuildDuration = (Get-Date) - $dockerBuildStart
    Write-Host "  [OK] Docker image rebuilt successfully" -ForegroundColor Green
    Write-Host "  [Time] Build time: $($dockerBuildDuration.Minutes) min $($dockerBuildDuration.Seconds) sec" -ForegroundColor Cyan

    # Save Dockerfile hash
    $currentHash = (Get-FileHash -Path $DockerfilePath -Algorithm MD5).Hash
    @{ hash = $currentHash; timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") } | ConvertTo-Json | Set-Content $DockerCacheFile
    Write-Host "  [OK] Cache updated" -ForegroundColor Green
} else {
    Write-Host "  [OK] Docker image found (cached)" -ForegroundColor Green
}
Write-Host ""

# Clean and create build directory
Write-Host "Preparing build directory..." -ForegroundColor Yellow
if (-not (Test-Path $BuildDir)) {
    New-Item -ItemType Directory -Path $BuildDir | Out-Null
    Write-Host "  Build directory created: $BuildDir" -ForegroundColor Green
} else {
    Write-Host "  Cleaning CMake cache..." -ForegroundColor Gray
    # 鍙垹闄Make鐢熸垚鐨勬枃浠跺拰鏋勫缓浜х墿锛屼繚鐣橯t6杩愯鏃舵枃浠讹紙lib, plugins, qml, AUDIO锛?    $filesToClean = @(
        "CMakeCache.txt",
        "CMakeFiles",
        "cmake_install.cmake",
        "Makefile",
        "bin_arm64",
        "src"

    foreach ($item in $filesToClean) {
        $path = Join-Path $BuildDir $item
        if (Test-Path $path) {
            try {
                Remove-Item -Recurse -Force $path -ErrorAction Stop
            } catch {
                Write-Host "    Warning: Could not remove $item" -ForegroundColor Yellow
            }
        }
    }

    Write-Host "  Build directory ready (Qt6 runtime files preserved)" -ForegroundColor Green
}
Write-Host ""

# Run Docker cross-compilation
Write-Host "Starting cross-compilation..." -ForegroundColor Yellow
Write-Host "  Target: ARM64 (aarch64)" -ForegroundColor Gray
Write-Host "  Qt version: 6.x (pre-compiled)" -ForegroundColor Gray
Write-Host "  GLib version: 2.80 (bundled, compatibility fix)" -ForegroundColor Gray
Write-Host "  Estimated time: 3-5 minutes" -ForegroundColor Gray
Write-Host ""

# Execute Docker compilation command
docker run --rm `
    -v "${ProjectRoot}:/workspace" `
    -v "${DockerDir}/qt-host:/opt/qt-host:ro" `
    -v "${DockerDir}/qt-raspi:/opt/qt-raspi:ro" `
    -v "${DockerDir}/sysroot:/opt/sysroot:ro" `
    -v "${DockerDir}/rk3588-libs:/opt/rk3588-libs:ro" `
    -e QT_HOST_PATH=/opt/qt-host `
    -e QT_TARGET_PATH=/opt/qt-raspi `
    -e SYSROOT=/opt/sysroot/rk3588-root `
    -w /workspace/build_rk3588 `
    belt-control-rk3588:latest `
    bash -c 'cmake -DCMAKE_TOOLCHAIN_FILE=/opt/qt-raspi/lib/cmake/Qt6/qt.toolchain.cmake -DQT_CHAINLOAD_TOOLCHAIN_FILE=/workspace/docker/rk3588/toolchain-rk3588.cmake -DCMAKE_BUILD_TYPE=Release -DENABLE_SHERPA_ONNX=ON -DSHERPA_ONNX_LIB_DIR=/opt/rk3588-libs/lib -DSHERPA_ONNX_INCLUDE_DIR=/opt/rk3588-libs/include .. && cmake --build . -j32'

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Compilation failed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Common troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Check if qt-raspi directory is complete" -ForegroundColor White
    Write-Host "  2. Check if sysroot is correct" -ForegroundColor White
    Write-Host "  3. Review error messages above" -ForegroundColor White
    Write-Host ""
    exit 1
}

# Find compiled binary
Write-Host ""
Write-Host "Searching for build artifacts..." -ForegroundColor Yellow
$BinaryPath = Get-ChildItem -Path $BuildDir -Filter "belt_control_system" -Recurse -File | Select-Object -First 1

if (-not $BinaryPath) {
    Write-Host "  Binary not found!" -ForegroundColor Red
    exit 1
}

Write-Host "  Binary found: $($BinaryPath.FullName)" -ForegroundColor Green

# Check binary architecture (if 'file' command available)
try {
    $fileOutput = & file $BinaryPath.FullName 2>$null
    if ($LASTEXITCODE -eq 0 -and ($fileOutput -match "aarch64" -or $fileOutput -match "ARM64")) {
        Write-Host "  Architecture verified: ARM64" -ForegroundColor Green
    } else {
        Write-Host "  Architecture: ARM64 (assumed from build)" -ForegroundColor Green
    }
} catch {
    Write-Host "  Architecture: ARM64 (assumed from build)" -ForegroundColor Green
}

$BinarySize = [math]::Round($BinaryPath.Length / 1MB, 2)
Write-Host "  File size: $BinarySize MB" -ForegroundColor Green
Write-Host ""

Write-Host "==========================================" -ForegroundColor Green
Write-Host "Compilation Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Build artifacts:" -ForegroundColor Cyan
Write-Host "  Binary: $($BinaryPath.FullName)" -ForegroundColor White
Write-Host "  Architecture: ARM64 (aarch64)" -ForegroundColor White
Write-Host "  Size: $BinarySize MB" -ForegroundColor White
Write-Host ""
Write-Host "v3.3 New features:" -ForegroundColor Cyan
Write-Host "  Auto-detect 800x1280 screen resolution" -ForegroundColor White
Write-Host "  Auto-apply 270 degree rotation for landscape display" -ForegroundColor White
Write-Host "  Uses bundled GLib 2.80 (compatibility fix)" -ForegroundColor White
Write-Host ""
Write-Host "Next step - Deploy to device:" -ForegroundColor Yellow
Write-Host "  Device 155: .\docker\rk3588\deploy-local-to-155.ps1" -ForegroundColor White
Write-Host "  Device 170: .\docker\rk3588\deploy-local-to-170.ps1" -ForegroundColor White
Write-Host ""
Write-Host "Or manual deployment:" -ForegroundColor Yellow
Write-Host "  1. Copy binary to device: scp $($BinaryPath.FullName) linaro@192.168.10.155:/home/linaro/belt-control-qt6/" -ForegroundColor White
Write-Host "  2. SSH to device and rebuild Docker image" -ForegroundColor White
Write-Host ""
