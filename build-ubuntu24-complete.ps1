# Complete Ubuntu 24.04 Build & Deploy Script
# Solves GLIBC 2.39 dependency issue by including complete system libraries
# 完全本地Windows离线构建，自动化部署到任何ARM64 RK3588设备

# Device configuration (can be changed via parameters)
param(
    [string]$DeviceIP = "192.168.10.188",
    [string]$DeviceUser = "linaro"
)

$ErrorActionPreference = "Stop"

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Ubuntu 24.04 Complete Build & Deploy" -ForegroundColor Cyan
Write-Host "Offline | Self-Contained | GLIBC 2.39" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$ProjectRoot = "e:\2025\3_gongkongji\belt_control_system"
$BuildDir = "$ProjectRoot\build_rk3588"
$BinaryFile = "$BuildDir\bin_arm64\belt_control_system"
$SysrootDir = "$ProjectRoot\docker\rk3588\sysroot\pi-root"
$DockerContextDir = "$ProjectRoot\docker_build_ubuntu24_complete"
$ImageName = "belt-control"
$ImageTag = "v3.4-ubuntu24"
$OutputTarFile = "$ProjectRoot\belt-control-ubuntu24.tar"

# ============================================================
# Step 1: Cross-compilation check
# ============================================================
Write-Host "Step 1: Cross-compilation check..." -ForegroundColor Cyan

$needCompile = $false

if (-not (Test-Path $BinaryFile)) {
    Write-Host "  Binary not found, compilation required" -ForegroundColor Yellow
    $needCompile = $true
} else {
    Write-Host "  Binary found: $(([System.IO.FileInfo]$BinaryFile).Length / 1MB) MB" -ForegroundColor Green
    Write-Host "  Checking source files..." -ForegroundColor Yellow

    $binaryTime = (Get-Item $BinaryFile).LastWriteTime
    $sourceFiles = Get-ChildItem -Path "$ProjectRoot\src" -Recurse -Include *.cpp,*.h,*.qml -File
    $newerFiles = $sourceFiles | Where-Object { $_.LastWriteTime -gt $binaryTime }

    if ($newerFiles) {
        Write-Host "  Found $($newerFiles.Count) source files newer than binary" -ForegroundColor Yellow
        $needCompile = $true
    } else {
        Write-Host "  No source changes detected" -ForegroundColor Green
        $needCompile = $false
    }
}

if ($needCompile) {
    Write-Host ""
    Write-Host "  Running cross-compilation..." -ForegroundColor White
    Write-Host ""

    & "$ProjectRoot\build-rk3588.ps1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "ERROR: Cross-compilation failed" -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "  ✅ Cross-compilation complete" -ForegroundColor Green
} else {
    Write-Host "  ✅ Using existing binary" -ForegroundColor Green
}
Write-Host ""

# ============================================================
# Step 2: Prepare Docker build context
# ============================================================
Write-Host "Step 2: Preparing Docker build context..." -ForegroundColor Cyan

# Clean and create build context directory
if (Test-Path $DockerContextDir) {
    Write-Host "  Cleaning old build context..." -ForegroundColor Yellow
    Remove-Item $DockerContextDir -Recurse -Force
}
New-Item -ItemType Directory -Path $DockerContextDir | Out-Null
Write-Host "  ✅ Build context directory created" -ForegroundColor Green

# Copy binary
Write-Host "  Copying application binary..." -ForegroundColor Yellow
Copy-Item $BinaryFile "$DockerContextDir\belt_control_system" -Force
Write-Host "  ✅ Binary copied" -ForegroundColor Green

# Helper function for fast directory copying
function Fast-Copy {
    param([string]$Source, [string]$Destination, [string]$Label)

    if (-not (Test-Path $Source)) {
        Write-Host "    ⚠️  $Label`: Source not found" -ForegroundColor Yellow
        return
    }

    if (-not (Test-Path $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    Write-Host "    Copying $Label..." -ForegroundColor Gray
    $result = robocopy $Source $Destination /E /NFL /NDL /NJH /NJS /nc /ns /np

    if ($LASTEXITCODE -lt 8) {
        Write-Host "    ✅ $Label copied" -ForegroundColor Green
    } else {
        Write-Host "    ❌ $Label copy failed" -ForegroundColor Red
        throw "Failed to copy $Label"
    }
}

# Copy Qt6 runtime files
Write-Host "  Copying Qt6 runtime files..." -ForegroundColor Yellow
Fast-Copy "$BuildDir\lib" "$DockerContextDir\lib" "Qt6 libraries"
Fast-Copy "$BuildDir\plugins" "$DockerContextDir\plugins" "Qt6 plugins"
Fast-Copy "$BuildDir\qml" "$DockerContextDir\qml" "QML files"

# ============================================================
# Step 3: Copy complete system libraries from sysroot
# ============================================================
Write-Host ""
Write-Host "Step 3: Copying complete system libraries (GLIBC 2.39)..." -ForegroundColor Cyan

$SysLibsDir = "$DockerContextDir\system_libs"
New-Item -ItemType Directory -Path $SysLibsDir -Force | Out-Null

# Copy CRITICAL system directories
Write-Host "  This includes ALL dependencies for offline operation" -ForegroundColor Yellow
Write-Host ""

# 1. Core GLIBC and linker (/lib/aarch64-linux-gnu)
Write-Host "  [1/4] Copying /lib/aarch64-linux-gnu (GLIBC 2.39 core)..." -ForegroundColor White
$libSrc = "$SysrootDir\lib\aarch64-linux-gnu"
$libDst = "$SysLibsDir\lib\aarch64-linux-gnu"
if (Test-Path $libSrc) {
    Fast-Copy $libSrc $libDst "GLIBC core libraries"
    Write-Host "  ✅ GLIBC 2.39 core copied" -ForegroundColor Green
} else {
    Write-Host "  ❌ GLIBC source not found!" -ForegroundColor Red
    exit 1
}

# 2. Application libraries (/usr/lib/aarch64-linux-gnu)
Write-Host "  [2/4] Copying /usr/lib/aarch64-linux-gnu (system libraries)..." -ForegroundColor White
$usrLibSrc = "$SysrootDir\usr\lib\aarch64-linux-gnu"
$usrLibDst = "$SysLibsDir\usr\lib\aarch64-linux-gnu"
if (Test-Path $usrLibSrc) {
    Fast-Copy $usrLibSrc $usrLibDst "System application libraries"
    Write-Host "  ✅ System libraries copied" -ForegroundColor Green
} else {
    Write-Host "  ⚠️  /usr/lib/aarch64-linux-gnu not found, may cause issues" -ForegroundColor Yellow
}

# 3. Optional: /lib (symlinks and additional libs)
Write-Host "  [3/4] Copying /lib (additional system libs)..." -ForegroundColor White
$libRootSrc = "$SysrootDir\lib"
$libRootDst = "$SysLibsDir\lib"
if (Test-Path $libRootSrc) {
    # Only copy .so files, skip subdirectories already copied
    Get-ChildItem -Path $libRootSrc -File -Filter "*.so*" | ForEach-Object {
        Copy-Item $_.FullName $libRootDst -Force
    }
    Write-Host "  ✅ Additional /lib files copied" -ForegroundColor Green
}

# 4. Optional: /usr/lib (non-arch-specific libs)
Write-Host "  [4/4] Copying /usr/lib (non-arch libs)..." -ForegroundColor White
$usrLibRootSrc = "$SysrootDir\usr\lib"
$usrLibRootDst = "$SysLibsDir\usr\lib"
if (Test-Path $usrLibRootSrc) {
    # Copy important subdirectories only
    $importantDirs = @("aarch64-linux-gnu", "gcc", "cmake")
    foreach ($dir in $importantDirs) {
        $src = Join-Path $usrLibRootSrc $dir
        $dst = Join-Path $usrLibRootDst $dir
        if (Test-Path $src) {
            Fast-Copy $src $dst "/usr/lib/$dir"
        }
    }
    Write-Host "  ✅ Non-arch libraries copied" -ForegroundColor Green
}

Write-Host ""
Write-Host "  ✅ All system libraries copied successfully" -ForegroundColor Green
Write-Host ""

# ============================================================
# Step 4: Create Dockerfile
# ============================================================
Write-Host "Step 4: Creating Dockerfile..." -ForegroundColor Cyan

$DockerfileContent = @'
FROM --platform=linux/arm64 ubuntu:24.04

# ==============================================================================
# Belt Control System v3.4 - Complete Ubuntu 24.04 Image
# Includes GLIBC 2.39 and all dependencies for offline operation
# ==============================================================================

# Stage 1: Copy and install system libraries
# ------------------------------------------------------------------------------
COPY system_libs /tmp/system_libs

RUN echo "=== Installing system libraries ===" && \
    mkdir -p /lib/aarch64-linux-gnu /usr/lib/aarch64-linux-gnu && \
    \
    # Copy GLIBC 2.39 core libraries
    if [ -d /tmp/system_libs/lib/aarch64-linux-gnu ]; then \
        echo "Copying GLIBC 2.39 core..." && \
        cp -P -r /tmp/system_libs/lib/aarch64-linux-gnu/* /lib/aarch64-linux-gnu/ 2>/dev/null || true; \
    fi && \
    \
    # Copy system application libraries
    if [ -d /tmp/system_libs/usr/lib/aarch64-linux-gnu ]; then \
        echo "Copying system application libraries..." && \
        cp -P -r /tmp/system_libs/usr/lib/aarch64-linux-gnu/* /usr/lib/aarch64-linux-gnu/ 2>/dev/null || true; \
    fi && \
    \
    # Copy additional /lib files
    if [ -d /tmp/system_libs/lib ] && [ "$(ls -A /tmp/system_libs/lib/*.so* 2>/dev/null)" ]; then \
        echo "Copying additional /lib files..." && \
        cp -P /tmp/system_libs/lib/*.so* /lib/ 2>/dev/null || true; \
    fi && \
    \
    # Copy /usr/lib subdirectories
    if [ -d /tmp/system_libs/usr/lib ]; then \
        echo "Copying /usr/lib subdirectories..." && \
        cp -P -r /tmp/system_libs/usr/lib/* /usr/lib/ 2>/dev/null || true; \
    fi && \
    \
    # Cleanup
    rm -rf /tmp/system_libs && \
    echo "System libraries installed successfully"

# Stage 2: Copy application files
# ------------------------------------------------------------------------------
WORKDIR /app

COPY belt_control_system /app/belt_control_system
COPY lib /app/lib
COPY plugins /app/plugins
COPY qml /app/qml

# Stage 3: Setup permissions and create symlinks
# ------------------------------------------------------------------------------
RUN echo "=== Setting up application ===" && \
    chmod +x /app/belt_control_system && \
    mkdir -p /app/data /app/config /app/tts_models /app/AUDIO && \
    \
    # Create symlinks for application libraries (Qt6, FFmpeg, etc.)
    echo "Creating symlinks for application libraries..." && \
    cd /app/lib && \
    for lib in libavcodec libavformat libavutil libavdevice libavfilter libavresample libswresample libswscale \
               libopus libmp3lame libogg libvorbis libvorbisenc libvorbisfile libtheora libspeex libvo-amrwbenc libyuv \
               libsherpa-onnx; do \
        if ls ${lib}.so.* 1> /dev/null 2>&1; then \
            latest=$(ls ${lib}.so.* | sort -V | tail -1); \
            version=$(echo $latest | sed "s/${lib}.so.//"); \
            major=$(echo $version | cut -d. -f1); \
            ln -sf $latest ${lib}.so.${major} 2>/dev/null || true; \
            ln -sf ${lib}.so.${major} ${lib}.so 2>/dev/null || true; \
        fi; \
    done && \
    \
    # Create symlinks for system libraries
    echo "Creating symlinks for system libraries..." && \
    cd /usr/lib/aarch64-linux-gnu && \
    for file in *.so.*.*; do \
        if [ -f "$file" ]; then \
            base=$(echo $file | sed 's/\.so\..*//' ); \
            version=$(echo $file | sed 's/.*\.so\.\([0-9]*\)\..*/\1/' ); \
            ln -sf $file ${base}.so.${version} 2>/dev/null || true; \
            ln -sf ${base}.so.${version} ${base}.so 2>/dev/null || true; \
        fi; \
    done && \
    \
    echo "Application setup complete"

# Stage 4: Environment variables
# ------------------------------------------------------------------------------
ENV LD_LIBRARY_PATH=/app/lib:/lib:/usr/lib:/lib/aarch64-linux-gnu:/usr/lib/aarch64-linux-gnu:$LD_LIBRARY_PATH \
    QT_PLUGIN_PATH=/app/plugins \
    QML2_IMPORT_PATH=/app/qml \
    QT_QPA_PLATFORM=eglfs \
    QT_QPA_EGLFS_INTEGRATION=eglfs_kms \
    QT_QPA_EGLFS_ALWAYS_SET_MODE=1

# Stage 5: Runtime
# ------------------------------------------------------------------------------
WORKDIR /app

# Healthcheck
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD test -f /app/belt_control_system && echo "OK" || exit 1

CMD ["/app/belt_control_system"]
'@

Set-Content -Path "$DockerContextDir\Dockerfile" -Value $DockerfileContent -Encoding UTF8
Write-Host "  ✅ Dockerfile created" -ForegroundColor Green
Write-Host ""

# ============================================================
# Step 5: Build Docker image
# ============================================================
Write-Host "Step 5: Building Docker image..." -ForegroundColor Cyan
Write-Host "  Image: ${ImageName}:${ImageTag}" -ForegroundColor White
Write-Host "  This may take 5-10 minutes..." -ForegroundColor Yellow
Write-Host ""

$buildStart = Get-Date
# Use Docker layer caching - only rebuild when Dockerfile or dependencies change
docker build --platform linux/arm64 -t "${ImageName}:${ImageTag}" $DockerContextDir

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Docker build failed" -ForegroundColor Red
    exit 1
}

$buildDuration = (Get-Date) - $buildStart
Write-Host ""
Write-Host "  ✅ Docker image built successfully" -ForegroundColor Green
Write-Host "  ⏱️  Build time: $($buildDuration.Minutes) min $($buildDuration.Seconds) sec" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Step 6: Verify image and dependencies
# ============================================================
Write-Host "Step 6: Verifying image dependencies..." -ForegroundColor Cyan

Write-Host "  Checking if all libraries are present..." -ForegroundColor Yellow
$lddOutput = docker run --rm --platform=linux/arm64 "${ImageName}:${ImageTag}" ldd /app/belt_control_system

Write-Host ""
Write-Host "=== LDD Output ===" -ForegroundColor White
Write-Host $lddOutput
Write-Host "==================" -ForegroundColor White
Write-Host ""

$notFound = $lddOutput | Select-String "not found"
if ($notFound) {
    Write-Host "  ❌ Missing libraries detected:" -ForegroundColor Red
    Write-Host $notFound
    Write-Host ""
    Write-Host "  ⚠️  Image may not work correctly. Continue anyway? (y/N)" -ForegroundColor Yellow
    $response = Read-Host
    if ($response -ne "y" -and $response -ne "Y") {
        Write-Host "  Aborting deployment" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  ✅ All dependencies satisfied!" -ForegroundColor Green
}
Write-Host ""

# ============================================================
# Step 7: Export and deploy to device
# ============================================================
Write-Host "Step 7: Export and deploy to device..." -ForegroundColor Cyan
Write-Host "  Target device: $DeviceUser@$DeviceIP" -ForegroundColor White
Write-Host ""

# Export to local tar file
Write-Host "  [1/4] Exporting image to tar..." -ForegroundColor Yellow
if (Test-Path $OutputTarFile) {
    Remove-Item $OutputTarFile -Force
}
docker save "${ImageName}:${ImageTag}" -o $OutputTarFile

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ Export failed" -ForegroundColor Red
    exit 1
}

$tarSize = [math]::Round((Get-Item $OutputTarFile).Length / 1GB, 2)
Write-Host "  ✅ Image exported: ${tarSize}GB" -ForegroundColor Green

# Upload to device
Write-Host "  [2/4] Uploading to device (this may take a few minutes)..." -ForegroundColor Yellow
$remoteTarPath = "/tmp/belt-control-ubuntu24.tar"
scp $OutputTarFile "${DeviceUser}@${DeviceIP}:${remoteTarPath}"

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ Upload failed" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Upload complete" -ForegroundColor Green

# Load on device
Write-Host "  [3/4] Loading image on device..." -ForegroundColor Yellow
ssh "${DeviceUser}@${DeviceIP}" "docker load -i $remoteTarPath && rm $remoteTarPath"

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ❌ Load failed" -ForegroundColor Red
    exit 1
}
Write-Host "  ✅ Image loaded on device" -ForegroundColor Green

# Create run script on device
Write-Host "  [4/4] Creating run script on device..." -ForegroundColor Yellow

$runScript = @"
#!/bin/bash
# Belt Control System v3.4 - Ubuntu 24.04 Complete Image
# Generated by build-ubuntu24-complete.ps1

sudo docker stop belt-control-app 2>/dev/null
sudo docker rm belt-control-app 2>/dev/null

echo "=========================================="
echo "Belt Control System v3.4"
echo "Ubuntu 24.04 | GLIBC 2.39"
echo "=========================================="
echo ""

xhost +local:docker 2>/dev/null || echo "xhost not available, trying anyway..."

echo "Starting application..."

sudo docker run \
    --name belt-control-app \
    --privileged \
    -e DISPLAY=:0 \
    -e QT_QPA_PLATFORM=xcb \
    -e XDG_RUNTIME_DIR=/tmp \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    -v /dev:/dev \
    -v /sys:/sys \
    -v /run/udev:/run/udev:ro \
    -v /usr/share/fonts:/usr/share/fonts:ro \
    ${ImageName}:${ImageTag}

EXIT_CODE=\$?
echo ""
echo "Application exited with code: \$EXIT_CODE"

if [ \$EXIT_CODE -ne 0 ]; then
    echo ""
    echo "Last 30 lines of logs:"
    sudo docker logs --tail 30 belt-control-app
fi
"@

$runScript | ssh "${DeviceUser}@${DeviceIP}" "cat > /home/$DeviceUser/run-ubuntu24.sh && chmod +x /home/$DeviceUser/run-ubuntu24.sh"

Write-Host "  ✅ Run script created: /home/$DeviceUser/run-ubuntu24.sh" -ForegroundColor Green
Write-Host ""

# Cleanup local tar file
Write-Host "  Cleaning up local tar file..." -ForegroundColor Gray
Remove-Item $OutputTarFile -Force
Write-Host "  ✅ Cleanup complete" -ForegroundColor Green
Write-Host ""

# ============================================================
# Final Summary
# ============================================================
Write-Host "===============================================" -ForegroundColor Green
Write-Host "✅ Build & Deploy Complete!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Image Details:" -ForegroundColor Cyan
Write-Host "  Name: ${ImageName}:${ImageTag}" -ForegroundColor White
Write-Host "  Base: Ubuntu 24.04 (GLIBC 2.39)" -ForegroundColor White
Write-Host "  Size: ${tarSize}GB" -ForegroundColor White
Write-Host ""
Write-Host "Deployment:" -ForegroundColor Cyan
Write-Host "  Device: $DeviceUser@$DeviceIP" -ForegroundColor White
Write-Host "  Status: ✅ Ready to run" -ForegroundColor Green
Write-Host ""
Write-Host "To run the application:" -ForegroundColor Yellow
Write-Host "  ssh $DeviceUser@$DeviceIP ./run-ubuntu24.sh" -ForegroundColor White
Write-Host ""
Write-Host "To test now: (y/N)" -ForegroundColor Yellow
$testNow = Read-Host

if ($testNow -eq "y" -or $testNow -eq "Y") {
    Write-Host ""
    Write-Host "Launching application on device..." -ForegroundColor Cyan
    ssh "${DeviceUser}@${DeviceIP}" "./run-ubuntu24.sh"
}
