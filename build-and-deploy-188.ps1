# Build and Deploy to Device 188 - No APT Version
# Avoids QEMU segfault by copying system libraries from sysroot instead of apt-get install
# 完全避免 QEMU 段错误问题

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Build & Deploy - Device 188 (No APT)" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$DeviceIP = "192.168.10.188"
$DeviceUser = "linaro"
$ProjectRoot = "e:\2025\3_gongkongji\belt_control_system"
$BuildDir = "$ProjectRoot\build_rk3588"
$BinaryFile = "$BuildDir\bin_arm64\belt_control_system"
$SysrootDir = "$ProjectRoot\docker\rk3588\sysroot\pi-root"

# Step 1: Check if cross-compilation needed
Write-Host "Step 1: Check if cross-compilation needed..." -ForegroundColor Cyan

$needCompile = $false

if (-not (Test-Path $BinaryFile)) {
    Write-Host "  Binary not found, compilation required" -ForegroundColor Yellow
    $needCompile = $true
} else {
    Write-Host "  Binary found, checking if source files changed..." -ForegroundColor Yellow
    $binaryTime = (Get-Item $BinaryFile).LastWriteTime
    $sourceFiles = Get-ChildItem -Path "$ProjectRoot\src" -Recurse -Include *.cpp,*.h,*.qml -File
    $newerFiles = $sourceFiles | Where-Object { $_.LastWriteTime -gt $binaryTime }

    if ($newerFiles) {
        Write-Host "  Found $($newerFiles.Count) source files newer than binary" -ForegroundColor Yellow
        $needCompile = $true
    } else {
        Write-Host "  No source changes detected, skipping compilation" -ForegroundColor Green
        $needCompile = $false
    }
}

if ($needCompile) {
    Write-Host ""
    Write-Host "  Running build-rk3588.ps1..." -ForegroundColor White
    Write-Host ""

    & "$PSScriptRoot\build-rk3588.ps1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "ERROR: Cross-compilation failed" -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "  Cross-compilation complete" -ForegroundColor Green
} else {
    Write-Host "  Using existing binary" -ForegroundColor Green
}
Write-Host ""

# Step 2: Prepare build context with system libraries
Write-Host "Step 2: Prepare build context with system libraries..." -ForegroundColor Cyan

$DockerContextDir = "$ProjectRoot\docker_build_context_noatp"
$ImageName = "belt-control"
$ImageTag = "v3.3-188-noatp"
$OutputTarFile = "$ProjectRoot\belt-control-188-noatp.tar"

# Create build context directory
if (-not (Test-Path $DockerContextDir)) {
    New-Item -ItemType Directory -Path $DockerContextDir | Out-Null
}

# Create system_libs directory
$SysLibsDir = "$DockerContextDir\system_libs"
if (-not (Test-Path $SysLibsDir)) {
    New-Item -ItemType Directory -Path $SysLibsDir | Out-Null
}

# Copy binary
Write-Host "  Copying binary..." -ForegroundColor Yellow
Copy-Item $BinaryFile "$DockerContextDir\belt_control_system" -Force
Write-Host "    Binary copied" -ForegroundColor Green

# Copy Qt6 runtime files (using robocopy for speed)
Write-Host "  Copying Qt6 runtime files..." -ForegroundColor Yellow

function Fast-Copy {
    param([string]$Source, [string]$Destination, [string]$Label)

    if (-not (Test-Path $Source)) {
        Write-Host "    $Label`: Source not found, skipping" -ForegroundColor Gray
        return
    }

    if (-not (Test-Path $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    # Use robocopy for fast copying
    $result = robocopy "$Source" "$Destination" /E /MT:8 /NFL /NDL /NJH /NJS /NC /NS /NP
    Write-Host "    $Label`: Copied" -ForegroundColor Green
}

Fast-Copy -Source "$BuildDir\lib" -Destination "$DockerContextDir\lib" -Label "Qt6 libraries"
Fast-Copy -Source "$BuildDir\plugins" -Destination "$DockerContextDir\plugins" -Label "Qt6 plugins"
Fast-Copy -Source "$BuildDir\qml" -Destination "$DockerContextDir\qml" -Label "QML files"

if (Test-Path "$BuildDir\AUDIO") {
    Fast-Copy -Source "$BuildDir\AUDIO" -Destination "$DockerContextDir\AUDIO" -Label "AUDIO files"
} else {
    Write-Host "    AUDIO files: Not found, skipping" -ForegroundColor Gray
}

# Copy Sherpa-ONNX libraries
$sherpaLibDir = "$ProjectRoot\libs\sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared\lib"
if (Test-Path $sherpaLibDir) {
    Write-Host "  Copying Sherpa-ONNX libraries..." -ForegroundColor Yellow
    Get-ChildItem -Path $sherpaLibDir -Filter "*.so" | ForEach-Object {
        Copy-Item $_.FullName -Destination "$DockerContextDir\lib\" -Force
    }
    Write-Host "    Sherpa-ONNX libraries copied" -ForegroundColor Green
} else {
    Write-Host "    Sherpa-ONNX libraries: Not found at $sherpaLibDir" -ForegroundColor Yellow
}

# Copy RK3588 multimedia libraries (FFmpeg 4.x, etc.)
$rk3588LibDir = "$ProjectRoot\docker\rk3588\rk3588-libs\lib"
if (Test-Path $rk3588LibDir) {
    Write-Host "  Copying RK3588 multimedia libraries (FFmpeg 4.x + codecs)..." -ForegroundColor Yellow
    $multimediaLibs = @(
        "libavcodec.so*", "libavformat.so*", "libavutil.so*",
        "libavdevice.so*", "libavfilter.so*", "libavresample.so*",
        "libswresample.so*", "libswscale.so*",
        "libopus.so*", "libmp3lame.so*", "libogg.so*", "libvorbis*",
        "libtheora.so*", "libspeex.so*", "libvo-amrwbenc.so*",
        "libyuv.so*", "libmali.so*", "librknnrt.so*", "libSDL2*.so*",
        "libv4l2.so*", "libx264.so*"
    )
    $copiedCount = 0
    foreach ($pattern in $multimediaLibs) {
        $files = Get-ChildItem -Path $rk3588LibDir -Filter $pattern -File -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            # Skip symlinks (LinkType property exists), only copy real files
            if (-not $file.LinkType) {
                Copy-Item $file.FullName -Destination "$DockerContextDir\lib\" -Force
                $copiedCount++
            }
        }
    }
    Write-Host "    RK3588 multimedia libraries: $copiedCount files copied (symlinks skipped)" -ForegroundColor Green

    # Remove ALL 0-byte symlink files (Windows symlinks show as 0 bytes)
    # This includes libavcodec.so, libavcodec.so.58, etc. - all are symlinks
    $symlinkFiles = Get-ChildItem -Path "$DockerContextDir\lib\" -Filter "*.so*" -File | Where-Object { $_.Length -eq 0 }
    if ($symlinkFiles) {
        foreach ($symlink in $symlinkFiles) {
            Remove-Item $symlink.FullName -Force
        }
        Write-Host "    Cleaned up $($symlinkFiles.Count) symlink files (will be recreated in container)" -ForegroundColor Gray
    }
} else {
    Write-Host "    RK3588 libs: Not found at $rk3588LibDir" -ForegroundColor Yellow
}

# Copy system libraries from sysroot
Write-Host "  Copying system libraries from sysroot..." -ForegroundColor Yellow

# Create lib subdirectories
$libDirs = @("lib", "lib\aarch64-linux-gnu", "usr\lib", "usr\lib\aarch64-linux-gnu")
foreach ($dir in $libDirs) {
    $srcDir = Join-Path $SysrootDir $dir
    if (Test-Path $srcDir) {
        $destDir = Join-Path $SysLibsDir $dir
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }

        # Copy specific libraries needed (avoid copying everything)
        # Note: FFmpeg libraries are copied from rk3588-libs above, not from sysroot
        $neededLibs = @(
            "libgles*", "libegl*", "libxcb*", "libxkb*", "libdbus*",
            "libfontconfig*", "libfreetype*", "libpng*", "libz*",
            "libx11*", "libxau*", "libxdmcp*", "libdrm*", "libgbm*",
            "libwayland*", "libglapi*", "libglvnd*", "libexpat*",
            "libbsd*", "libmd*", "libasound*", "libalsa*",
            "libglib-2.0*", "libharfbuzz*", "libicu*", "libpcre2*",
            "libbrotli*", "libpulse*", "libv4l2*", "libSDL2*",
            "libmali*", "librknnrt*", "libx264*"
        )

        foreach ($pattern in $neededLibs) {
            Get-ChildItem -Path $srcDir -Filter $pattern -File -ErrorAction SilentlyContinue | ForEach-Object {
                Copy-Item $_.FullName -Destination $destDir -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
Write-Host "    System libraries copied" -ForegroundColor Green

# Create Dockerfile (without apt-get)
$dockerfile = @'
FROM --platform=linux/arm64 ubuntu:22.04

# Copy system libraries using a temp directory first
COPY system_libs /tmp/system_libs

# Use RUN to copy system libraries (no apt-get to avoid QEMU issues)
RUN mkdir -p /lib/aarch64-linux-gnu /usr/lib/aarch64-linux-gnu && \
    if [ -d /tmp/system_libs/lib ] && [ "$(ls -A /tmp/system_libs/lib 2>/dev/null)" ]; then \
        cp -r /tmp/system_libs/lib/* /lib/ 2>/dev/null || true; \
    fi && \
    if [ -d /tmp/system_libs/lib/aarch64-linux-gnu ] && [ "$(ls -A /tmp/system_libs/lib/aarch64-linux-gnu 2>/dev/null)" ]; then \
        cp -r /tmp/system_libs/lib/aarch64-linux-gnu/* /lib/aarch64-linux-gnu/ 2>/dev/null || true; \
    fi && \
    if [ -d /tmp/system_libs/usr/lib ] && [ "$(ls -A /tmp/system_libs/usr/lib 2>/dev/null)" ]; then \
        cp -r /tmp/system_libs/usr/lib/* /usr/lib/ 2>/dev/null || true; \
    fi && \
    if [ -d /tmp/system_libs/usr/lib/aarch64-linux-gnu ] && [ "$(ls -A /tmp/system_libs/usr/lib/aarch64-linux-gnu 2>/dev/null)" ]; then \
        cp -r /tmp/system_libs/usr/lib/aarch64-linux-gnu/* /usr/lib/aarch64-linux-gnu/ 2>/dev/null || true; \
    fi && \
    rm -rf /tmp/system_libs

# Copy application files
WORKDIR /app
COPY belt_control_system /app/belt_control_system
COPY lib /app/lib
COPY plugins /app/plugins
COPY qml /app/qml

# Setup permissions, directories, and create symlinks for all multimedia and system libraries
RUN chmod +x /app/belt_control_system && \
    mkdir -p /app/data /app/config /app/tts_models /app/AUDIO && \
    cd /app/lib && \
    for lib in libavcodec libavformat libavutil libavdevice libavfilter libavresample libswresample libswscale \
               libopus libmp3lame libogg libvorbis libvorbisenc libvorbisfile libtheora libspeex libvo-amrwbenc libyuv; do \
        if ls ${lib}.so.* 1> /dev/null 2>&1; then \
            latest=$(ls ${lib}.so.* | sort -V | tail -1); \
            version=$(echo $latest | sed "s/${lib}.so.//"); \
            major=$(echo $version | cut -d. -f1); \
            ln -sf $latest ${lib}.so.${major} 2>/dev/null || true; \
            ln -sf ${lib}.so.${major} ${lib}.so 2>/dev/null || true; \
        fi; \
    done && \
    cd /usr/lib/aarch64-linux-gnu && \
    for file in *.so.*.*; do \
        if [ -f "$file" ]; then \
            base=$(echo $file | sed 's/\.so\..*//' ); \
            version=$(echo $file | sed 's/.*\.so\.\([0-9]*\)\..*/\1/' ); \
            ln -sf $file ${base}.so.${version} 2>/dev/null || true; \
            ln -sf ${base}.so.${version} ${base}.so 2>/dev/null || true; \
        fi; \
    done

# Environment variables
ENV LD_LIBRARY_PATH=/app/lib:/lib:/usr/lib:/usr/lib/aarch64-linux-gnu:$LD_LIBRARY_PATH
ENV QT_PLUGIN_PATH=/app/plugins
ENV QML2_IMPORT_PATH=/app/qml
ENV QT_QPA_PLATFORM=eglfs
ENV QT_QPA_EGLFS_INTEGRATION=eglfs_kms
ENV QT_QPA_EGLFS_ALWAYS_SET_MODE=1

WORKDIR /app
CMD ["/app/belt_control_system"]
'@
$dockerfile | Out-File -Encoding UTF8 "$DockerContextDir\Dockerfile"

# Step 3: Build ARM64 image
Write-Host ""
Write-Host "Step 3: Build ARM64 Docker image..." -ForegroundColor Cyan
Write-Host "  Using simple Dockerfile without apt-get (avoiding QEMU issues)" -ForegroundColor White
Write-Host "  Force rebuild (no cache)..." -ForegroundColor Gray
Write-Host ""

docker buildx build --no-cache --platform linux/arm64 --tag "${ImageName}:${ImageTag}" --load "$DockerContextDir"
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Docker build failed" -ForegroundColor Red
    exit 1
}

Write-Host "  Image built successfully" -ForegroundColor Green
Write-Host ""

# Step 4: Export to tar
Write-Host "Step 4: Export image to tar..." -ForegroundColor Cyan
docker save "${ImageName}:${ImageTag}" -o "$OutputTarFile"
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Export failed" -ForegroundColor Red
    exit 1
}

$imageSize = [math]::Round((Get-Item $OutputTarFile).Length / 1MB, 2)
Write-Host "  Exported: $imageSize MB" -ForegroundColor Green
Write-Host ""

# Cleanup
Remove-Item -Recurse -Force $DockerContextDir

# Step 5: Transfer to device
Write-Host "Step 5: Transfer image to device 188..." -ForegroundColor Cyan
Write-Host "  Target: $DeviceUser@$DeviceIP" -ForegroundColor White
Write-Host "  Size: $imageSize MB" -ForegroundColor White

scp "$OutputTarFile" "${DeviceUser}@${DeviceIP}:/tmp/belt-control-188.tar"
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Transfer failed" -ForegroundColor Red
    exit 1
}
Write-Host "  Transferred successfully" -ForegroundColor Green
Write-Host ""

# Step 6: Load on device
Write-Host "Step 6: Load image on device..." -ForegroundColor Cyan
ssh "${DeviceUser}@${DeviceIP}" 'sudo docker load -i /tmp/belt-control-188.tar && rm /tmp/belt-control-188.tar'
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Load failed" -ForegroundColor Red
    exit 1
}
Write-Host "  Image loaded" -ForegroundColor Green
Write-Host ""

# Step 7: Create run script
Write-Host "Step 7: Create run script..." -ForegroundColor Cyan
$runScript = @'
#!/bin/bash
# Belt Control System v3.3 - Device 188

sudo docker stop belt-control-app 2>/dev/null
sudo docker rm belt-control-app 2>/dev/null

echo "=========================================="
echo "Belt Control System v3.3 - Device 188"
echo "No-APT build (避免 QEMU 问题)"
echo "=========================================="
echo ""

xhost +local:docker 2>/dev/null || echo "xhost not available, trying anyway..."
DISPLAY=:0 xrandr --output DSI-1 --rotate left 2>/dev/null

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
    belt-control:v3.3-188-noatp

EXIT_CODE=$?
echo ""
echo "Application exited with code: $EXIT_CODE"

if [ $EXIT_CODE -ne 0 ]; then
    echo ""
    echo "Last 30 lines of logs:"
    sudo docker logs --tail 30 belt-control-app
fi
'@

$runScript | ssh "${DeviceUser}@${DeviceIP}" 'cat > /home/linaro/run-188-noatp.sh && chmod +x /home/linaro/run-188-noatp.sh'
Write-Host "  Run script created: /home/linaro/run-188-noatp.sh" -ForegroundColor Green
Write-Host ""

# Cleanup local tar
Write-Host "Cleaning up local tar file..." -ForegroundColor Cyan
Remove-Item $OutputTarFile
Write-Host "  Cleaned" -ForegroundColor Green
Write-Host ""

Write-Host "==========================================" -ForegroundColor Green
Write-Host "Build & Deploy Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Image size: $imageSize MB" -ForegroundColor White
Write-Host ""
Write-Host "To run the application:" -ForegroundColor Yellow
Write-Host "  ssh ${DeviceUser}@${DeviceIP} ./run-188-noatp.sh" -ForegroundColor White
Write-Host ""
