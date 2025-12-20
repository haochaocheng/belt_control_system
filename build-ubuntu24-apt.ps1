# Complete Ubuntu 24.04 Build & Deploy Script (apt-get method)
# Uses Ubuntu 24.04 native packages via apt-get with smart caching
# 完全本地Windows离线构建，自动化部署到任何ARM64 RK3588设备
#
# 使用方法:
#   .\build-ubuntu24-apt.ps1 151        # 部署到 192.168.10.151
#   .\build-ubuntu24-apt.ps1 188        # 部署到 192.168.10.188
#   .\build-ubuntu24-apt.ps1 192.168.10.200  # 部署到自定义IP

param(
    [string]$Device = "151"  # 默认151设备
)

$ErrorActionPreference = "Stop"

# ============================================================
# Parse device parameter and setup configuration
# ============================================================
$DeviceUser = "linaro"
$DevicePassword = "linaro"

switch -Regex ($Device) {
    "^151$" {
        $DeviceIP = "192.168.10.151"
        Write-Host "[Device] Target: Device 151 ($DeviceIP)" -ForegroundColor Cyan
    }
    "^188$" {
        $DeviceIP = "192.168.10.188"
        Write-Host "[Device] Target: Device 188 ($DeviceIP)" -ForegroundColor Cyan
    }
    "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$" {
        $DeviceIP = $Device
        Write-Host "[Device] Target: Custom IP ($DeviceIP)" -ForegroundColor Cyan
    }
    default {
        Write-Host "[ERROR] Invalid device parameter: $Device" -ForegroundColor Red
        Write-Host ""
        Write-Host "Usage:" -ForegroundColor Yellow
        Write-Host "  .\build-ubuntu24-apt.ps1 151              # Deploy to 192.168.10.151" -ForegroundColor White
        Write-Host "  .\build-ubuntu24-apt.ps1 188              # Deploy to 192.168.10.188" -ForegroundColor White
        Write-Host "  .\build-ubuntu24-apt.ps1 192.168.10.200   # Deploy to custom IP" -ForegroundColor White
        Write-Host ""
        exit 1
    }
}

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "Ubuntu 24.04 Smart Build & Deploy" -ForegroundColor Cyan
Write-Host "Native packages | Smart caching | GLIBC 2.39" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$ProjectRoot = "e:\2025\3_gongkongji\belt_control_system"
$BuildDir = "$ProjectRoot\build_rk3588"
$BinaryFile = "$BuildDir\bin_arm64\belt_control_system"
$DockerContextDir = "$ProjectRoot\docker_build_ubuntu24_apt"
$BaseImageName = "belt-control-base"
$BaseImageTag = "ubuntu24"
$AppImageName = "belt-control"
$AppImageTag = "v3.5-apt"
$OutputTarFile = "$ProjectRoot\belt-control-ubuntu24-apt.tar"
$BaseCacheFile = "$ProjectRoot\.docker_base_cache.json"
$AppCacheFile = "$ProjectRoot\.docker_app_cache.json"

# ============================================================
# Step 0: Check and build base image if needed
# ============================================================
Write-Host "Step 0: Checking base image..." -ForegroundColor Cyan

$baseImageExists = docker images -q "${BaseImageName}:${BaseImageTag}" 2>$null
$needBuildBase = $false

if (-not $baseImageExists) {
    Write-Host "  [!] Base image not found" -ForegroundColor Yellow
    $needBuildBase = $true
} else {
    # Check if Dockerfile.ubuntu24-base changed
    $baseDockerfilePath = "$ProjectRoot\Dockerfile.ubuntu24-base"
    if (Test-Path $baseDockerfilePath) {
        $currentBaseHash = (Get-FileHash -Path $baseDockerfilePath -Algorithm MD5).Hash

        if (Test-Path $BaseCacheFile) {
            $cacheData = Get-Content $BaseCacheFile | ConvertFrom-Json
            $previousBaseHash = $cacheData.hash

            if ($previousBaseHash -ne $currentBaseHash) {
                Write-Host "  [!] Base Dockerfile changed - rebuild required" -ForegroundColor Yellow
                $needBuildBase = $true
            }
        } else {
            # No cache file, assume need rebuild
            $needBuildBase = $true
        }
    }
}

if ($needBuildBase) {
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host "  Base Image Build Required" -ForegroundColor Yellow
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Need to download ~200MB system dependencies" -ForegroundColor Yellow
    Write-Host "  Estimated time: 5-10 minutes" -ForegroundColor Yellow
    Write-Host "  Recommended: Enable VPN/proxy for faster download" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "VPN/proxy ready? Press any key to continue..." -ForegroundColor Cyan
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Write-Host ""

    Write-Host "  Building base image (this happens ONCE)..." -ForegroundColor Yellow
    $baseBuildStart = Get-Date

    docker build --platform linux/arm64 -f "$ProjectRoot\Dockerfile.ubuntu24-base" -t "${BaseImageName}:${BaseImageTag}" "$ProjectRoot"

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "ERROR: Base image build failed" -ForegroundColor Red
        exit 1
    }

    $baseBuildDuration = (Get-Date) - $baseBuildStart
    Write-Host "  [OK] Base image built successfully" -ForegroundColor Green
    Write-Host "  [Time] Build time: $($baseBuildDuration.Minutes) min $($baseBuildDuration.Seconds) sec" -ForegroundColor Cyan

    # Save base image hash
    $baseDockerfilePath = "$ProjectRoot\Dockerfile.ubuntu24-base"
    if (Test-Path $baseDockerfilePath) {
        $currentBaseHash = (Get-FileHash -Path $baseDockerfilePath -Algorithm MD5).Hash
        @{ hash = $currentBaseHash; timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") } | ConvertTo-Json | Set-Content $BaseCacheFile
    }
} else {
    Write-Host "  [OK] Base image found (cached, no download needed)" -ForegroundColor Green
}
Write-Host ""

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
    Write-Host "  Running cross-compilation with GLIBC fix (32 threads)..." -ForegroundColor White
    Write-Host ""

    & "$ProjectRoot\build-rk3588-fixed.ps1"
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "ERROR: Cross-compilation failed" -ForegroundColor Red
        exit 1
    }

    Write-Host ""
    Write-Host "  [OK] Cross-compilation complete" -ForegroundColor Green
} else {
    Write-Host "  [OK] Using existing binary" -ForegroundColor Green
}
Write-Host ""

# ============================================================
# Step 2: Prepare Docker build context (NO sysroot copying)
# ============================================================
Write-Host "Step 2: Preparing Docker build context..." -ForegroundColor Cyan

# Clean and create build context directory
if (Test-Path $DockerContextDir) {
    Write-Host "  Cleaning old build context..." -ForegroundColor Yellow
    Remove-Item $DockerContextDir -Recurse -Force
}
New-Item -ItemType Directory -Path $DockerContextDir | Out-Null
Write-Host "  [OK] Build context directory created" -ForegroundColor Green

# Copy binary
Write-Host "  Copying application binary..." -ForegroundColor Yellow
Copy-Item $BinaryFile "$DockerContextDir\belt_control_system" -Force
Write-Host "  [OK] Binary copied" -ForegroundColor Green

# Copy TTS service executable
$TtsServiceFile = "$ProjectRoot\build_tts_arm64\sherpa_tts_service"
if (Test-Path $TtsServiceFile) {
    Write-Host "  Copying TTS service executable..." -ForegroundColor Yellow
    Copy-Item $TtsServiceFile "$DockerContextDir\sherpa_tts_service" -Force
    Write-Host "  [OK] TTS service copied" -ForegroundColor Green
} else {
    Write-Host "  [!] TTS service not found at $TtsServiceFile (TTS disabled)" -ForegroundColor Yellow
}

# Helper function for fast directory copying (resolving symlinks to real files)
function Fast-Copy {
    param([string]$Source, [string]$Destination, [string]$Label)

    if (-not (Test-Path $Source)) {
        Write-Host "    WARNING: ${Label}: Source not found" -ForegroundColor Yellow
        return
    }

    if (-not (Test-Path $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }

    Write-Host "    Copying $Label..." -ForegroundColor Gray
    # Use robocopy with /SL to follow symlinks and copy actual file content
    # This ensures Docker build context doesn't contain symlinks
    $result = robocopy $Source $Destination /E /SL /NFL /NDL /NJH /NJS /nc /ns /np

    if ($LASTEXITCODE -lt 8) {
        Write-Host "    OK: ${Label} copied" -ForegroundColor Green
    } else {
        Write-Host "    ERROR: ${Label} copy failed" -ForegroundColor Red
        throw "Failed to copy ${Label}"
    }
}

# Copy Qt6 runtime files
Write-Host "  Copying Qt6 runtime files..." -ForegroundColor Yellow
Fast-Copy "$ProjectRoot\docker\rk3588\qt-raspi\lib" "$DockerContextDir\lib" "Qt6 libraries"
Fast-Copy "$ProjectRoot\docker\rk3588\qt-raspi\plugins" "$DockerContextDir\plugins" "Qt6 plugins"
Fast-Copy "$ProjectRoot\docker\rk3588\qt-raspi\qml" "$DockerContextDir\qml" "QML files"

# Copy additional required libraries from RK3588 libs and sysroot
Write-Host "  Copying additional required libraries..." -ForegroundColor Yellow

# Copy libmali (Mali GPU driver)
$MaliLibPath = "$ProjectRoot\docker\rk3588\rk3588-libs\lib"
if (Test-Path $MaliLibPath) {
    Write-Host "    Copying libmali..." -ForegroundColor Gray
    if (-not (Test-Path "$DockerContextDir\lib")) {
        New-Item -ItemType Directory -Path "$DockerContextDir\lib" -Force | Out-Null
    }
    Copy-Item "$MaliLibPath\libmali.so*" "$DockerContextDir\lib\" -Force -ErrorAction SilentlyContinue
    Write-Host "    OK: libmali copied" -ForegroundColor Green
}

# Copy FFmpeg (version 4.x with .58), sherpa-onnx, libyuv, libxcb-dri2 from device-build
# IMPORTANT: Only copy REAL files (not symlinks) to avoid Docker build context errors
$DeviceBuildLibPath = "$ProjectRoot\docker\rk3588\device-build\libs"
if (Test-Path $DeviceBuildLibPath) {
    Write-Host "    Copying FFmpeg 4.x libraries (real files only)..." -ForegroundColor Gray
    # Only copy real files with full version numbers (e.g., libavcodec.so.58.134.100)
    Get-ChildItem -Path $DeviceBuildLibPath -Filter "libavcodec.so.*.*.*" -File | Where-Object { $_.Length -gt 0 } | ForEach-Object { Copy-Item $_.FullName "$DockerContextDir\lib\" -Force }
    Get-ChildItem -Path $DeviceBuildLibPath -Filter "libavutil.so.*.*.*" -File | Where-Object { $_.Length -gt 0 } | ForEach-Object { Copy-Item $_.FullName "$DockerContextDir\lib\" -Force }
    Get-ChildItem -Path $DeviceBuildLibPath -Filter "libavformat.so.*.*.*" -File | Where-Object { $_.Length -gt 0 } | ForEach-Object { Copy-Item $_.FullName "$DockerContextDir\lib\" -Force }
    Get-ChildItem -Path $DeviceBuildLibPath -Filter "libswscale.so.*.*.*" -File | Where-Object { $_.Length -gt 0 } | ForEach-Object { Copy-Item $_.FullName "$DockerContextDir\lib\" -Force }
    Get-ChildItem -Path $DeviceBuildLibPath -Filter "libswresample.so.*.*.*" -File | Where-Object { $_.Length -gt 0 } | ForEach-Object { Copy-Item $_.FullName "$DockerContextDir\lib\" -Force }
    Write-Host "    OK: FFmpeg 4.x libraries copied" -ForegroundColor Green

    Write-Host "    Copying sherpa-onnx TTS library..." -ForegroundColor Gray
    Get-ChildItem -Path $DeviceBuildLibPath -Filter "libsherpa-onnx*.so.*.*.*" -File | Where-Object { $_.Length -gt 0 } | ForEach-Object { Copy-Item $_.FullName "$DockerContextDir\lib\" -Force -ErrorAction SilentlyContinue }
    Write-Host "    OK: sherpa-onnx copied" -ForegroundColor Green

    Write-Host "    Copying libonnxruntime (RKNN acceleration)..." -ForegroundColor Yellow
    $OnnxRuntimePath = "$ProjectRoot\libs\sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared\lib\libonnxruntime.so"
    if (Test-Path $OnnxRuntimePath) {
        Copy-Item $OnnxRuntimePath "$DockerContextDir\lib\" -Force
        Write-Host "    OK: libonnxruntime copied (RKNN hardware acceleration)" -ForegroundColor Green
    } else {
        Write-Host "    WARNING: libonnxruntime not found - TTS may not work!" -ForegroundColor Red
    }

    Write-Host "    Copying libyuv..." -ForegroundColor Gray
    Get-ChildItem -Path $DeviceBuildLibPath -Filter "libyuv.so.*" -File | Where-Object { $_.Length -gt 0 } | ForEach-Object { Copy-Item $_.FullName "$DockerContextDir\lib\" -Force -ErrorAction SilentlyContinue }
    Write-Host "    OK: libyuv copied" -ForegroundColor Green

    Write-Host "    Copying libxcb-dri2..." -ForegroundColor Gray
    Get-ChildItem -Path $DeviceBuildLibPath -Filter "libxcb-dri2.so.*" -File | Where-Object { $_.Length -gt 0 } | ForEach-Object { Copy-Item $_.FullName "$DockerContextDir\lib\" -Force -ErrorAction SilentlyContinue }
    Write-Host "    OK: libxcb-dri2 copied" -ForegroundColor Green
}

# Copy libxcb-dri2 from sysroot if not found in device-build
$XcbPath = "$ProjectRoot\docker\rk3588\sysroot\pi-root\lib\aarch64-linux-gnu"
if (Test-Path $XcbPath) {
    Write-Host "    Copying libxcb-dri2 from sysroot..." -ForegroundColor Gray
    Get-ChildItem -Path $XcbPath -Filter "libxcb-dri2.so.*.*.*" -File | Where-Object { $_.Length -gt 0 } | ForEach-Object { Copy-Item $_.FullName "$DockerContextDir\lib\" -Force -ErrorAction SilentlyContinue }
    Write-Host "    OK: libxcb-dri2 from sysroot copied" -ForegroundColor Green
}

# Copy librknnrt (RK3588 NPU runtime - REQUIRED for RKNN acceleration)
$RknnLibPath = "$ProjectRoot\docker\rk3588\rk3588-libs\lib"
if (Test-Path $RknnLibPath) {
    Write-Host "    Copying librknnrt (RK3588 NPU runtime)..." -ForegroundColor Yellow
    Get-ChildItem -Path $RknnLibPath -Filter "librknnrt.so*" -File | Where-Object { $_.Length -gt 0 } | ForEach-Object { Copy-Item $_.FullName "$DockerContextDir\lib\" -Force }
    Write-Host "    OK: librknnrt copied (RKNN acceleration enabled)" -ForegroundColor Green
} else {
    Write-Host "    WARNING: librknnrt not found - RKNN acceleration will NOT work!" -ForegroundColor Red
}

# Copy ICU and PCRE2 from RK3588 libs directory (not qt-raspi!)
# IMPORTANT: Only copy REAL files (not symlinks) to avoid Docker build context errors
$RK3588LibPath = "$ProjectRoot\docker\rk3588\rk3588-libs\lib"
if (Test-Path $RK3588LibPath) {
    Write-Host "    Copying ICU libraries (Qt6 dependencies, real files only)..." -ForegroundColor Gray
    Get-ChildItem -Path $RK3588LibPath -Filter "libicui18n.so.*.*" -File | Where-Object { $_.Length -gt 0 } | ForEach-Object { Copy-Item $_.FullName "$DockerContextDir\lib\" -Force -ErrorAction SilentlyContinue }
    Get-ChildItem -Path $RK3588LibPath -Filter "libicuuc.so.*.*" -File | Where-Object { $_.Length -gt 0 } | ForEach-Object { Copy-Item $_.FullName "$DockerContextDir\lib\" -Force -ErrorAction SilentlyContinue }
    Get-ChildItem -Path $RK3588LibPath -Filter "libicudata.so.*.*" -File | Where-Object { $_.Length -gt 0 } | ForEach-Object { Copy-Item $_.FullName "$DockerContextDir\lib\" -Force -ErrorAction SilentlyContinue }
    Write-Host "    OK: ICU libraries copied" -ForegroundColor Green

    Write-Host "    Copying PCRE2-16 (Qt6 dependency, real files only)..." -ForegroundColor Gray
    Get-ChildItem -Path $RK3588LibPath -Filter "libpcre2-16.so.*.*" -File | Where-Object { $_.Length -gt 0 } | ForEach-Object { Copy-Item $_.FullName "$DockerContextDir\lib\" -Force -ErrorAction SilentlyContinue }
    Write-Host "    OK: PCRE2-16 copied" -ForegroundColor Green

    Write-Host "    Copying libx264 (H.264 encoder, REQUIRED)..." -ForegroundColor Yellow
    Get-ChildItem -Path $RK3588LibPath -Filter "libx264.so.*" -File | Where-Object { $_.Length -gt 0 } | ForEach-Object { Copy-Item $_.FullName "$DockerContextDir\lib\" -Force }
    Write-Host "    OK: libx264 copied" -ForegroundColor Green
} else {
    Write-Host "    WARNING: RK3588 libs not found" -ForegroundColor Red
}

# Copy TTS models (vits-zh-aishell3)
Write-Host "  Copying TTS models..." -ForegroundColor Yellow
$TtsModelsSource = "$ProjectRoot\libs\tts_models"
if (Test-Path $TtsModelsSource) {
    $ttsModels = Get-ChildItem -Path $TtsModelsSource -Directory
    Write-Host "    Found $($ttsModels.Count) TTS models" -ForegroundColor Gray

    foreach ($model in $ttsModels) {
        $modelSize = [math]::Round((Get-ChildItem -Path $model.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB, 1)
        Write-Host "    Copying $($model.Name) (${modelSize}MB)..." -ForegroundColor Gray
        Fast-Copy $model.FullName "$DockerContextDir\tts_models\$($model.Name)" "TTS model: $($model.Name)"
    }
    Write-Host "    OK: TTS models copied" -ForegroundColor Green
} else {
    Write-Host "    WARNING: TTS models directory not found" -ForegroundColor Red
    Write-Host "    TTS will be disabled. Please ensure $TtsModelsSource exists" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  [OK] All application files prepared" -ForegroundColor Green
Write-Host "  Note: System libraries already in base image (cached)" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Step 3: Create Dockerfile (uses base image)
# ============================================================
Write-Host "Step 3: Using Dockerfile with base image..." -ForegroundColor Cyan

# Copy the Dockerfile.ubuntu24-apt to build context
Copy-Item "$ProjectRoot\Dockerfile.ubuntu24-apt" "$DockerContextDir\Dockerfile" -Force
Write-Host "  [OK] Dockerfile prepared (using cached base image)" -ForegroundColor Green
Write-Host ""

# ============================================================
# Step 4: Build Docker application image
# ============================================================
Write-Host "Step 4: Building application image..." -ForegroundColor Cyan
Write-Host "  Image: ${AppImageName}:${AppImageTag}" -ForegroundColor White
Write-Host "  Base: ${BaseImageName}:${BaseImageTag} (cached)" -ForegroundColor White

# Smart cache: Only use --no-cache if binary/TTS/Dockerfile changed
$useNoCache = $false
$appBinaryPath = "$DockerContextDir\belt_control_system"
$ttsBinaryPath = "$DockerContextDir\sherpa_tts_service"
$appDockerfilePath = "$ProjectRoot\Dockerfile.ubuntu24-apt"

if ((Test-Path $appBinaryPath) -and (Test-Path $ttsBinaryPath) -and (Test-Path $appDockerfilePath)) {
    $appHash = (Get-FileHash -Path $appBinaryPath -Algorithm MD5).Hash
    $ttsHash = (Get-FileHash -Path $ttsBinaryPath -Algorithm MD5).Hash
    $dockerfileHash = (Get-FileHash -Path $appDockerfilePath -Algorithm MD5).Hash
    $currentHash = "$appHash|$ttsHash|$dockerfileHash"

    if (Test-Path $AppCacheFile) {
        $cacheData = Get-Content $AppCacheFile | ConvertFrom-Json
        $previousHash = $cacheData.hash

        if ($previousHash -ne $currentHash) {
            Write-Host "  Detected changes - rebuilding application layer" -ForegroundColor Yellow
            $useNoCache = $true
        } else {
            Write-Host "  No changes - using Docker cache" -ForegroundColor Green
        }
    } else {
        Write-Host "  First build - building application layer" -ForegroundColor Yellow
        $useNoCache = $true
    }

    # Save hash
    @{ hash = $currentHash; timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") } | ConvertTo-Json | Set-Content $AppCacheFile
}

Write-Host "  Estimated time: 1-2 minutes (no dependency download)..." -ForegroundColor Yellow
Write-Host ""

$buildStart = Get-Date
$buildArgs = @("build", "--platform", "linux/arm64")
if ($useNoCache) {
    $buildArgs += "--no-cache"
}
$buildArgs += @("-t", "${AppImageName}:${AppImageTag}", $DockerContextDir)

& docker $buildArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Docker build failed" -ForegroundColor Red
    exit 1
}

$buildDuration = (Get-Date) - $buildStart
Write-Host ""
Write-Host "  [OK] Application image built successfully" -ForegroundColor Green
Write-Host "  [Time] Build time: $($buildDuration.Minutes) min $($buildDuration.Seconds) sec" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Step 5: Verify image and dependencies
# ============================================================
Write-Host "Step 5: Verifying image dependencies..." -ForegroundColor Cyan

Write-Host "  Checking if all libraries are present..." -ForegroundColor Yellow
$lddOutput = docker run --rm --platform=linux/arm64 "${AppImageName}:${AppImageTag}" ldd /app/belt_control_system

Write-Host ""
Write-Host "=== LDD Output ===" -ForegroundColor White
Write-Host $lddOutput
Write-Host "==================" -ForegroundColor White
Write-Host ""

$notFound = $lddOutput | Select-String "not found"
if ($notFound) {
    Write-Host "  [ERROR] Missing libraries detected:" -ForegroundColor Red
    Write-Host $notFound
    Write-Host ""
    Write-Host "  [!] Image may not work correctly. Continue anyway? (y/N)" -ForegroundColor Yellow
    $response = Read-Host
    if ($response -ne "y" -and $response -ne "Y") {
        Write-Host "  Aborting deployment" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "  [OK] All dependencies satisfied!" -ForegroundColor Green
}
Write-Host ""

# ============================================================
# Step 6: Export and deploy to device
# ============================================================
Write-Host "Step 6: Export and deploy to device..." -ForegroundColor Cyan
Write-Host "  Target device: $DeviceUser@$DeviceIP" -ForegroundColor White
Write-Host ""

# Export to local tar file
Write-Host "  [1/4] Exporting image to tar..." -ForegroundColor Yellow
if (Test-Path $OutputTarFile) {
    Remove-Item $OutputTarFile -Force
}
docker save "${AppImageName}:${AppImageTag}" -o $OutputTarFile

if ($LASTEXITCODE -ne 0) {
    Write-Host "  [ERROR] Export failed" -ForegroundColor Red
    exit 1
}

$tarSize = [math]::Round((Get-Item $OutputTarFile).Length / 1GB, 2)
Write-Host "  [OK] Image exported: ${tarSize}GB" -ForegroundColor Green

# Upload to device
Write-Host "  [2/4] Uploading to device (this may take a few minutes)..." -ForegroundColor Yellow
$remoteTarPath = "/tmp/belt-control-ubuntu24-apt.tar"
scp $OutputTarFile "${DeviceUser}@${DeviceIP}:${remoteTarPath}"

if ($LASTEXITCODE -ne 0) {
    Write-Host "  [ERROR] Upload failed" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Upload complete" -ForegroundColor Green

# Load on device
Write-Host "  [3/4] Loading image on device..." -ForegroundColor Yellow
ssh "${DeviceUser}@${DeviceIP}" "docker load -i $remoteTarPath && rm $remoteTarPath"

if ($LASTEXITCODE -ne 0) {
    Write-Host "  [ERROR] Load failed" -ForegroundColor Red
    exit 1
}
Write-Host "  [OK] Image loaded on device" -ForegroundColor Green

# Create run script on device
Write-Host "  [4/4] Creating run script on device..." -ForegroundColor Yellow

# Use single-quote here-string to avoid variable expansion issues, then manually replace needed variables
$runScript = @'
#!/bin/bash
# Belt Control System v3.5 - Ubuntu 24.04 apt-get Method
# Generated by build-ubuntu24-apt.ps1

sudo docker stop belt-control-app 2>/dev/null
sudo docker rm belt-control-app 2>/dev/null

echo "=========================================="
echo "Belt Control System v3.5"
echo "Ubuntu 24.04 | apt-get native packages"
echo "Data persistence enabled"
echo "=========================================="
echo ""

# Create persistent data directory if not exists (unified appdata)
mkdir -p /home/DEVICE_USER_PLACEHOLDER/belt-control-data/appdata
mkdir -p /home/DEVICE_USER_PLACEHOLDER/belt-control-data/audio

# Auto-detect Qt platform based on X11 availability
if xhost +local:docker 2>/dev/null; then
    echo "✅ X11 detected - using XCB platform (windowed mode)"
    QT_PLATFORM=xcb
    DISPLAY_ARG="-e DISPLAY=:0"
    X11_VOLUME="-v /tmp/.X11-unix:/tmp/.X11-unix:rw"
else
    echo "✅ No X11 - using EGLFS platform (fullscreen mode)"
    QT_PLATFORM=eglfs
    DISPLAY_ARG=""
    X11_VOLUME=""
fi

echo "Starting application with persistent data..."
echo "Qt Platform: $QT_PLATFORM"

sudo docker run \
    --name belt-control-app \
    --privileged \
    --ipc=host \
    $DISPLAY_ARG \
    -e QT_QPA_PLATFORM=$QT_PLATFORM \
    -e XDG_RUNTIME_DIR=/tmp \
    $X11_VOLUME \
    -v /dev:/dev \
    -v /dev/dri:/dev/dri \
    -v /sys:/sys \
    -v /run/udev:/run/udev:ro \
    -v /usr/share/fonts:/usr/share/fonts:ro \
    -v /home/DEVICE_USER_PLACEHOLDER/belt-control-data/appdata:/app/appdata:rw \
    -v /home/DEVICE_USER_PLACEHOLDER/belt-control-data/audio:/app/AUDIO:rw \
    IMAGE_NAME_PLACEHOLDER:IMAGE_TAG_PLACEHOLDER

EXIT_CODE=$?
echo ""
echo "Application exited with code: $EXIT_CODE"

if [ $EXIT_CODE -ne 0 ]; then
    echo ""
    echo "Last 30 lines of logs:"
    sudo docker logs --tail 30 belt-control-app
fi
'@

# Replace placeholders with actual values
$runScript = $runScript -replace "DEVICE_USER_PLACEHOLDER", $DeviceUser
$runScript = $runScript -replace "IMAGE_NAME_PLACEHOLDER", $AppImageName
$runScript = $runScript -replace "IMAGE_TAG_PLACEHOLDER", $AppImageTag

# Convert Windows CRLF to Unix LF (fix line ending issue)
$runScript = $runScript -replace "`r`n", "`n"

$runScript | ssh "${DeviceUser}@${DeviceIP}" "cat > /home/$DeviceUser/run-ubuntu24-apt.sh && chmod +x /home/$DeviceUser/run-ubuntu24-apt.sh"

Write-Host "  [OK] Run script created: /home/$DeviceUser/run-ubuntu24-apt.sh" -ForegroundColor Green
Write-Host ""

# Cleanup local tar file
Write-Host "  Cleaning up local tar file..." -ForegroundColor Gray
if (Test-Path $OutputTarFile) {
    Remove-Item $OutputTarFile -Force
    Write-Host "  [OK] Cleanup complete" -ForegroundColor Green
} else {
    Write-Host "  [OK] No cleanup needed (file already removed)" -ForegroundColor Green
}
Write-Host ""

# ============================================================
# Final Summary
# ============================================================
Write-Host "===============================================" -ForegroundColor Green
Write-Host "[SUCCESS] Build & Deploy Complete!" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Image Details:" -ForegroundColor Cyan
Write-Host "  Name: ${AppImageName}:${AppImageTag}" -ForegroundColor White
Write-Host "  Base: ${BaseImageName}:${BaseImageTag} (cached)" -ForegroundColor White
Write-Host "  Method: Smart caching (fast rebuild)" -ForegroundColor White
Write-Host "  Size: ${tarSize}GB" -ForegroundColor White
Write-Host ""
Write-Host "Deployment:" -ForegroundColor Cyan
Write-Host "  Device: $DeviceUser@$DeviceIP" -ForegroundColor White
Write-Host "  Status: [OK] Ready to run" -ForegroundColor Green
Write-Host ""
Write-Host "To run the application:" -ForegroundColor Yellow
Write-Host "  ssh $DeviceUser@$DeviceIP ./run-ubuntu24-apt.sh" -ForegroundColor White
Write-Host ""
Write-Host "To test now: (y/N)" -ForegroundColor Yellow
$testNow = Read-Host

if ($testNow -eq "y" -or $testNow -eq "Y") {
    Write-Host ""
    Write-Host "Launching application on device..." -ForegroundColor Cyan
    ssh "${DeviceUser}@${DeviceIP}" "./run-ubuntu24-apt.sh"
}
