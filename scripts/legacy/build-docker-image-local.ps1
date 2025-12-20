# Build ARM64 Docker Image Locally on Windows
# Uses Docker buildx for multi-architecture support
# No device required - completely offline build

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Local ARM64 Docker Image Build" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$ProjectRoot = "e:\2025\3_gongkongji\belt_control_system"
$BuildDir = "$ProjectRoot\build_rk3588"
$BinaryFile = "$BuildDir\bin_arm64\belt_control_system"
$DockerContextDir = "$ProjectRoot\docker_build_context"
$ImageName = "belt-control"
$ImageTag = "v3.3-fullscreen-arm64"
$OutputTarFile = "$ProjectRoot\belt-control-arm64-local.tar"

# Check binary
Write-Host "Checking ARM64 binary..." -ForegroundColor Cyan
if (-not (Test-Path $BinaryFile)) {
    Write-Host "  ERROR: Binary not found" -ForegroundColor Red
    Write-Host "  Please run build-rk3588.ps1 first" -ForegroundColor Yellow
    exit 1
}
$binarySize = [math]::Round((Get-Item $BinaryFile).Length / 1MB, 2)
Write-Host "  Binary found: $binarySize MB" -ForegroundColor Green
Write-Host ""

# Check Docker buildx
Write-Host "Checking Docker buildx..." -ForegroundColor Cyan
try {
    $buildxVersion = docker buildx version 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Docker buildx not available"
    }
    Write-Host "  Docker buildx ready" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Docker buildx not found" -ForegroundColor Red
    Write-Host "  Please install Docker Desktop with buildx support" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# Smart copy function - only copies changed files
function Smart-Copy {
    param(
        [string]$Source,
        [string]$Destination,
        [string]$Label
    )

    Write-Host "  Processing $Label..." -ForegroundColor Yellow

    if (-not (Test-Path $Source)) {
        Write-Host "    Source not found, skipping" -ForegroundColor Gray
        return
    }

    $copied = 0
    $skipped = 0
    $startTime = Get-Date

    # Ensure destination directory exists
    if (-not (Test-Path $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    # Get all files from source
    $sourceFiles = Get-ChildItem -Path $Source -Recurse -File

    foreach ($srcFile in $sourceFiles) {
        $relativePath = $srcFile.FullName.Substring($Source.Length).TrimStart('\', '/')
        $destFile = Join-Path $Destination $relativePath

        # Check if we need to copy
        $needCopy = $false

        if (-not (Test-Path $destFile)) {
            # File doesn't exist in destination
            $needCopy = $true
        } else {
            # Compare file sizes first (faster than hash)
            $srcSize = $srcFile.Length
            $destSize = (Get-Item $destFile).Length

            if ($srcSize -ne $destSize) {
                $needCopy = $true
            } else {
                # Sizes match, compare hashes
                $srcHash = (Get-FileHash -Path $srcFile.FullName -Algorithm MD5).Hash
                $destHash = (Get-FileHash -Path $destFile -Algorithm MD5).Hash
                if ($srcHash -ne $destHash) {
                    $needCopy = $true
                }
            }
        }

        if ($needCopy) {
            # Create destination directory if needed
            $destDir = Split-Path $destFile -Parent
            if (-not (Test-Path $destDir)) {
                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
            }
            Copy-Item -Path $srcFile.FullName -Destination $destFile -Force
            $copied++
        } else {
            $skipped++
        }
    }

    $elapsed = (Get-Date) - $startTime
    $total = $copied + $skipped
    Write-Host "    $Label`: $copied copied, $skipped skipped ($total total) [" -NoNewline -ForegroundColor Green
    Write-Host "$([math]::Round($elapsed.TotalSeconds, 1))s" -NoNewline -ForegroundColor Cyan
    Write-Host "]" -ForegroundColor Green
}

# Create build context directory
Write-Host "Preparing build context..." -ForegroundColor Cyan
if (-not (Test-Path $DockerContextDir)) {
    New-Item -ItemType Directory -Path $DockerContextDir | Out-Null
}
if (-not (Test-Path "$DockerContextDir\AUDIO")) {
    New-Item -ItemType Directory -Path "$DockerContextDir\AUDIO" | Out-Null
}

# Copy binary (always copy - it's just one file)
Copy-Item $BinaryFile "$DockerContextDir\belt_control_system" -Force
Write-Host "  Binary copied" -ForegroundColor Green

# Smart copy runtime files from build directory
Smart-Copy -Source "$BuildDir\lib" -Destination "$DockerContextDir\lib" -Label "Qt6 libraries"
Smart-Copy -Source "$BuildDir\plugins" -Destination "$DockerContextDir\plugins" -Label "Qt6 plugins"
Smart-Copy -Source "$BuildDir\qml" -Destination "$DockerContextDir\qml" -Label "QML files"
Smart-Copy -Source "$BuildDir\AUDIO" -Destination "$DockerContextDir\AUDIO" -Label "AUDIO files"

Write-Host ""

# Create Dockerfile for local build
Write-Host "Creating Dockerfile..." -ForegroundColor Cyan
$dockerfile = @'
# Belt Control System v3.3 - ARM64 Docker Image
# Built locally on Windows using Docker buildx

FROM --platform=linux/arm64 ubuntu:22.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libgles2 \
    libegl1 \
    libxcb1 \
    libxcb-xkb1 \
    libxkbcommon-x11-0 \
    libxkbcommon0 \
    libdbus-1-3 \
    libfontconfig1 \
    libfreetype6 \
    libpng16-16 \
    zlib1g \
    libx11-6 \
    libx11-xcb1 \
    libxcb-glx0 \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-keysyms1 \
    libxcb-randr0 \
    libxcb-render-util0 \
    libxcb-render0 \
    libxcb-shape0 \
    libxcb-shm0 \
    libxcb-sync1 \
    libxcb-xfixes0 \
    libxcb-xinerama0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy application files
COPY belt_control_system /app/belt_control_system
COPY lib /app/lib
COPY plugins /app/plugins
COPY qml /app/qml
COPY AUDIO /app/AUDIO

# Set executable permissions
RUN chmod +x /app/belt_control_system

# Create data directories
RUN mkdir -p /app/data /app/config /app/tts_models

# Create symlinks for GLib libraries
RUN cd /app/lib && \
    if [ -f libglib-2.0.so.0.8000.0 ]; then ln -sf libglib-2.0.so.0.8000.0 libglib-2.0.so.0; fi && \
    if [ -f libgobject-2.0.so.0.8000.0 ]; then ln -sf libgobject-2.0.so.0.8000.0 libgobject-2.0.so.0; fi && \
    if [ -f libgio-2.0.so.0.8000.0 ]; then ln -sf libgio-2.0.so.0.8000.0 libgio-2.0.so.0; fi && \
    if [ -f libgmodule-2.0.so.0.8000.0 ]; then ln -sf libgmodule-2.0.so.0.8000.0 libgmodule-2.0.so.0; fi

# Set environment variables
ENV LD_LIBRARY_PATH=/app/lib:$LD_LIBRARY_PATH
ENV QT_PLUGIN_PATH=/app/plugins
ENV QML2_IMPORT_PATH=/app/qml
ENV QT_QPA_PLATFORM=eglfs
ENV QT_QPA_EGLFS_INTEGRATION=eglfs_kms
ENV QT_QPA_EGLFS_ALWAYS_SET_MODE=1
ENV LD_PRELOAD=/app/lib/libglib-2.0.so.0:/app/lib/libgobject-2.0.so.0:/app/lib/libgio-2.0.so.0

WORKDIR /app

CMD ["/app/belt_control_system"]
'@

$dockerfile | Out-File -Encoding UTF8 "$DockerContextDir\Dockerfile"
Write-Host "  Dockerfile created" -ForegroundColor Green
Write-Host ""

# Build ARM64 image using buildx
Write-Host "Building ARM64 Docker image..." -ForegroundColor Cyan
Write-Host "  Platform: linux/arm64" -ForegroundColor White
Write-Host "  This may take 5-10 minutes..." -ForegroundColor Gray
Write-Host ""

# Use default builder (already running, no network needed)
Write-Host "  Using existing Docker builder..." -ForegroundColor Yellow
docker buildx use default 2>&1 | Out-Null

# Build the image
Write-Host "  Building ARM64 image..." -ForegroundColor Yellow
docker buildx build `
    --platform linux/arm64 `
    --tag "${ImageName}:${ImageTag}" `
    --load `
    "$DockerContextDir"

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Docker build failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "  Image built successfully" -ForegroundColor Green
Write-Host ""

# Export image to tar file
Write-Host "Exporting image to tar file..." -ForegroundColor Cyan
docker save "${ImageName}:${ImageTag}" -o "$OutputTarFile"
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Failed to export image" -ForegroundColor Red
    exit 1
}

$imageSize = [math]::Round((Get-Item $OutputTarFile).Length / 1MB, 2)
Write-Host "  Exported: $imageSize MB" -ForegroundColor Green
Write-Host ""

# Cleanup build context
Write-Host "Cleaning up..." -ForegroundColor Cyan
Remove-Item -Recurse -Force $DockerContextDir
Write-Host "  Build context cleaned" -ForegroundColor Green
Write-Host ""

Write-Host "==========================================" -ForegroundColor Green
Write-Host "Build Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Image file: $OutputTarFile" -ForegroundColor White
Write-Host "Size: $imageSize MB" -ForegroundColor White
Write-Host "Image tag: ${ImageName}:${ImageTag}" -ForegroundColor White
Write-Host ""
Write-Host "Deployment options:" -ForegroundColor Yellow
Write-Host "  1. Transfer to device:" -ForegroundColor White
Write-Host "     scp ""$OutputTarFile"" linaro@192.168.10.188:/tmp/" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Load on device:" -ForegroundColor White
Write-Host "     ssh linaro@192.168.10.188 'sudo docker load -i /tmp/belt-control-arm64-local.tar'" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Run on device:" -ForegroundColor White
Write-Host "     ssh linaro@192.168.10.188 'docker run --rm --privileged <options> ${ImageName}:${ImageTag}'" -ForegroundColor Gray
Write-Host ""
