# Build and Deploy v3.3 with Rotation Fix
# This script:
# 1. Builds ARM64 binary using Docker cross-compilation environment
# 2. Packages binary + Qt6 + libs
# 3. Deploys to 155 device
# 4. Builds Docker image v3.3 on device

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$RemoteHost = "192.168.10.155"
$RemoteUser = "linaro"
$RemoteDeployDir = "/home/linaro/belt-control-qt6"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Build and Deploy v3.3 - Rotation Fix" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Build ARM64 binary using Docker
Write-Host "Step 1/5: Building ARM64 binary..." -ForegroundColor Yellow
Write-Host "  Using Docker cross-compilation environment" -ForegroundColor Gray

$BuildDir = "$ProjectRoot\build_rk3588_v3.3"
if (Test-Path $BuildDir) {
    Write-Host "  Cleaning old build directory..." -ForegroundColor Gray
    Remove-Item -Recurse -Force $BuildDir
}
New-Item -ItemType Directory -Path $BuildDir | Out-Null

# Run CMake configuration and build using Docker
Write-Host "  Configuring CMake..." -ForegroundColor Gray
docker run --rm `
    -v "${ProjectRoot}:/workspace" `
    -v "${ScriptDir}/qt-host:/opt/qt-host:ro" `
    -v "${ScriptDir}/qt-raspi:/opt/qt-raspi:ro" `
    -v "${ScriptDir}/sysroot:/opt/sysroot:ro" `
    -v "${ScriptDir}/rk3588-libs:/opt/rk3588-libs:ro" `
    -e QT_HOST_PATH=/opt/qt-host `
    -e QT_TARGET_PATH=/opt/qt-raspi `
    -e SYSROOT=/opt/sysroot/pi-root `
    -w /workspace/$([System.IO.Path]::GetFileName($BuildDir)) `
    belt-control-rk3588:latest `
    bash -c "cmake -DCMAKE_TOOLCHAIN_FILE=/opt/qt-raspi/lib/cmake/Qt6/qt.toolchain.cmake -DQT_CHAINLOAD_TOOLCHAIN_FILE=/workspace/docker/rk3588/toolchain-rk3588.cmake -DCMAKE_BUILD_TYPE=Release -DENABLE_SHERPA_ONNX=ON .. && cmake --build . -j8"

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Build failed!" -ForegroundColor Red
    exit 1
}

$BinaryPath = "$BuildDir\bin_arm64\belt_control_system"
if (-not (Test-Path $BinaryPath)) {
    Write-Host "  ERROR: Binary not found at $BinaryPath" -ForegroundColor Red
    exit 1
}

Write-Host "  OK Binary built successfully" -ForegroundColor Green
Write-Host ""

# Step 2: Create deployment package
Write-Host "Step 2/5: Creating deployment package..." -ForegroundColor Yellow

$TempDeployDir = "$env:TEMP\belt-control-v3.3-deploy"
if (Test-Path $TempDeployDir) {
    Remove-Item -Recurse -Force $TempDeployDir
}
New-Item -ItemType Directory -Path $TempDeployDir | Out-Null

# Copy binary
Copy-Item $BinaryPath "$TempDeployDir\belt_control_system" -Force
Write-Host "  OK Copied binary" -ForegroundColor Green

# Create Dockerfile.v3.3
$DockerfileContent = @"
# Belt Control v3.3 - With Screen Rotation Fix
FROM belt-control-base:trixie-noglib-v3.0

WORKDIR /app

# 复制应用程序
COPY belt_control_system /app/
RUN chmod +x /app/belt_control_system

# 关键修复: 强制优先使用打包的GLib 2.80库
ENV LD_PRELOAD=/app/libs/libglib-2.0.so.0:/app/libs/libgobject-2.0.so.0:/app/libs/libgio-2.0.so.0:/app/libs/libgmodule-2.0.so.0
ENV LD_LIBRARY_PATH=/app/libs:/opt/qt6/lib
ENV QT_PLUGIN_PATH=/opt/qt6/plugins
ENV QML2_IMPORT_PATH=/opt/qt6/qml
ENV QT_QPA_PLATFORM=eglfs
ENV QT_QPA_EGLFS_INTEGRATION=eglfs_kms

# 创建配置和数据目录
RUN mkdir -p /app/config /app/data

CMD ["/app/belt_control_system"]
"@

Set-Content -Path "$TempDeployDir\Dockerfile.v3.3" -Value $DockerfileContent -Encoding UTF8
Write-Host "  OK Created Dockerfile.v3.3" -ForegroundColor Green

# Create deployment script
$DeployScriptContent = @"
#!/bin/bash
# Build and run Belt Control v3.3

echo "Building Docker image belt-control:v3.3..."
docker build -f Dockerfile.v3.3 -t belt-control:v3.3 .

if [ \$? -ne 0 ]; then
    echo "ERROR: Docker build failed!"
    exit 1
fi

echo ""
echo "Docker image built successfully!"
echo "Image: belt-control:v3.3"
echo ""
echo "To run the application, use:"
echo "  ./run-v3.3.sh"
"@

Set-Content -Path "$TempDeployDir\build-v3.3.sh" -Value $DeployScriptContent -Encoding UTF8 -NoNewline
Write-Host "  OK Created build script" -ForegroundColor Green

# Create run script
$RunScriptContent = @"
#!/bin/bash
# Run Belt Control v3.3 with screen rotation fix

docker run --rm \
  --privileged \
  --group-add 44 \
  --device=/dev/mali0 \
  --device=/dev/fb0 \
  --device=/dev/dri/card0 \
  --device=/dev/dri/renderD128 \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v /run/udev:/run/udev:ro \
  belt-control:v3.3
"@

Set-Content -Path "$TempDeployDir\run-v3.3.sh" -Value $RunScriptContent -Encoding UTF8 -NoNewline
Write-Host "  OK Created run script" -ForegroundColor Green

# Compress package
Write-Host "  Compressing package..." -ForegroundColor Gray
$PackagePath = "$env:TEMP\belt-control-v3.3.tar.gz"
if (Test-Path $PackagePath) {
    Remove-Item $PackagePath -Force
}

Push-Location $TempDeployDir
& tar -czf $PackagePath .
Pop-Location

if (-not (Test-Path $PackagePath)) {
    Write-Host "  ERROR: Failed to create package" -ForegroundColor Red
    exit 1
}

$PackageSize = [math]::Round((Get-Item $PackagePath).Length / 1MB, 2)
Write-Host "  OK Package created ($PackageSize MB)" -ForegroundColor Green
Write-Host ""

# Step 3: Transfer to device
Write-Host "Step 3/5: Transferring to device..." -ForegroundColor Yellow

# Transfer package
Write-Host "  Uploading package to ${RemoteUser}@${RemoteHost}..." -ForegroundColor Gray
& scp $PackagePath "${RemoteUser}@${RemoteHost}:/tmp/belt-control-v3.3.tar.gz"

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Transfer failed!" -ForegroundColor Red
    Remove-Item $PackagePath -Force -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $TempDeployDir -ErrorAction SilentlyContinue
    exit 1
}

Write-Host "  OK Package transferred" -ForegroundColor Green

# Extract on device
Write-Host "  Extracting on device..." -ForegroundColor Gray
& ssh ${RemoteUser}@${RemoteHost} "cd $RemoteDeployDir && tar -xzf /tmp/belt-control-v3.3.tar.gz && rm /tmp/belt-control-v3.3.tar.gz && chmod +x build-v3.3.sh run-v3.3.sh"

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Extraction failed!" -ForegroundColor Red
    exit 1
}

Write-Host "  OK Files extracted" -ForegroundColor Green
Write-Host ""

# Cleanup local files
Remove-Item $PackagePath -Force -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $TempDeployDir -ErrorAction SilentlyContinue

# Step 4: Build Docker image on device
Write-Host "Step 4/5: Building Docker image on device..." -ForegroundColor Yellow
Write-Host "  This may take 1-2 minutes..." -ForegroundColor Gray

& ssh ${RemoteUser}@${RemoteHost} "cd $RemoteDeployDir && bash build-v3.3.sh"

if ($LASTEXITCODE -ne 0) {
    Write-Host "  ERROR: Docker build failed!" -ForegroundColor Red
    exit 1
}

Write-Host "  OK Docker image built" -ForegroundColor Green
Write-Host ""

# Step 5: Verify
Write-Host "Step 5/5: Verification..." -ForegroundColor Yellow

& ssh ${RemoteUser}@${RemoteHost} "docker images | grep 'belt-control.*v3.3'"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Application deployed with rotation fix" -ForegroundColor Cyan
Write-Host "Image: belt-control:v3.3" -ForegroundColor Cyan
Write-Host ""
Write-Host "To run on device 155:" -ForegroundColor Yellow
Write-Host "  ssh ${RemoteUser}@${RemoteHost}" -ForegroundColor White
Write-Host "  cd $RemoteDeployDir" -ForegroundColor White
Write-Host "  ./run-v3.3.sh" -ForegroundColor White
Write-Host ""
Write-Host "Changes in v3.3:" -ForegroundColor Yellow
Write-Host "  - Auto-detects 800x1280 screen resolution" -ForegroundColor White
Write-Host "  - Applies 270° rotation for correct landscape display" -ForegroundColor White
Write-Host "  - QML-level transformation (not Qt platform plugin)" -ForegroundColor White
Write-Host ""
