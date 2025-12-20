# Ubuntu 24.04 构建脚本 - 利用已编译的Qt、库和TTS
param(
    [switch]$BuildOnly = $false,
    [switch]$DeployOnly = $false,
    [string]$TargetDevice = "192.168.10.188"
)

$ErrorActionPreference = "Stop"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Ubuntu 24.04 ARM64 Build System" -ForegroundColor Cyan
Write-Host "Using existing Qt, libs and TTS" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

$ProjectRoot = "e:/2025/3_gongkongji/belt_control_system"
$DockerFile = "$ProjectRoot/docker/ubuntu24-new/Dockerfile"
$ImageName = "belt-control:ubuntu24-new"

# Check required resources
$requiredPaths = @{
    "Qt Host" = "$ProjectRoot/docker/rk3588/qt-host"
    "Qt Raspi" = "$ProjectRoot/docker/rk3588/qt-raspi"
    "RK3588 Libs" = "$ProjectRoot/docker/rk3588/rk3588-libs"
    "Sherpa-ONNX" = "$ProjectRoot/libs/sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared"
}

Write-Host "`nChecking compiled resources..." -ForegroundColor Green
$allFound = $true
foreach ($item in $requiredPaths.GetEnumerator()) {
    if (Test-Path $item.Value) {
        Write-Host "  [OK] $($item.Key): Found" -ForegroundColor Green
    } else {
        Write-Host "  [ERROR] $($item.Key): Not found - $($item.Value)" -ForegroundColor Red
        $allFound = $false
    }
}

if (-not $allFound) {
    Write-Host "`nMissing required resources" -ForegroundColor Red
    exit 1
}

if (-not $DeployOnly) {
    Write-Host "`n[1/3] Building Docker compile image..." -ForegroundColor Yellow
    docker build -f $DockerFile -t $ImageName ($ProjectRoot + "/docker/ubuntu24-new")

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker image build failed"
        exit 1
    }

    Write-Host "`n[2/3] Compiling project..." -ForegroundColor Yellow

    # Create build directory
    $buildDir = "$ProjectRoot/build_ubuntu24_arm64"
    if (Test-Path $buildDir) {
        Remove-Item -Recurse -Force $buildDir
    }
    New-Item -ItemType Directory -Path $buildDir | Out-Null

    # Run compilation with all required resources mounted
    docker run --rm `
        -v "${ProjectRoot}:/workspace" `
        -v "${ProjectRoot}/docker/rk3588/qt-host:/opt/qt-host:ro" `
        -v "${ProjectRoot}/docker/rk3588/qt-raspi:/opt/qt-raspi:ro" `
        -v "${ProjectRoot}/docker/rk3588/rk3588-libs:/opt/libs:ro" `
        -v "${ProjectRoot}/libs/sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared:/opt/sherpa-onnx:ro" `
        -e QT_HOST_PATH=/opt/qt-host `
        -e QT_TARGET_PATH=/opt/qt-raspi `
        $ImageName

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Compilation failed"
        exit 1
    }

    # Check output
    $outputFile = "$buildDir/belt_control_system"
    if (Test-Path $outputFile) {
        $size = (Get-Item $outputFile).Length / 1MB
        Write-Host "[OK] Compilation successful: belt_control_system ($([Math]::Round($size, 2)) MB)" -ForegroundColor Green
    } else {
        Write-Error "Compilation output not found"
        exit 1
    }
}

if (-not $BuildOnly) {
    Write-Host "`n[3/3] Building runtime image..." -ForegroundColor Yellow

    # Create deployment context
    $deployContext = "$ProjectRoot/docker_deploy_context"
    if (Test-Path $deployContext) {
        Remove-Item -Recurse -Force $deployContext
    }
    New-Item -ItemType Directory -Path $deployContext | Out-Null

    # Create runtime Dockerfile
    $dockerContent = @'
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    libqt6core6t64 \
    libqt6gui6t64 \
    libqt6widgets6t64 \
    libqt6network6t64 \
    libqt6qml6 \
    libqt6quick6 \
    qml6-module-qtquick \
    qml6-module-qtquick-controls \
    libgles2-mesa \
    libegl1-mesa \
    libasound2 \
    libpulse0 \
    libssl3t64 \
    fonts-noto-cjk \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY belt_control_system /app/
COPY config /app/config/
COPY libs/tts_models /app/libs/tts_models/
COPY libs/sherpa-onnx /app/libs/sherpa-onnx/

RUN chmod +x /app/belt_control_system

ENV QT_QPA_PLATFORM=eglfs
ENV LD_LIBRARY_PATH=/app/libs/sherpa-onnx/lib:$LD_LIBRARY_PATH

CMD ["/app/belt_control_system"]
'@

    # Write Dockerfile
    $dockerContent | Out-File -Encoding UTF8 "$deployContext/Dockerfile"

    # Copy files to context
    Copy-Item "$buildDir/belt_control_system" "$deployContext/" -ErrorAction SilentlyContinue
    Copy-Item -Recurse "$ProjectRoot/config" "$deployContext/" -ErrorAction SilentlyContinue

    if (Test-Path "$ProjectRoot/libs/tts_models") {
        New-Item -ItemType Directory -Path "$deployContext/libs" -Force | Out-Null
        Copy-Item -Recurse "$ProjectRoot/libs/tts_models" "$deployContext/libs/"
        Copy-Item -Recurse "$ProjectRoot/libs/sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared" "$deployContext/libs/sherpa-onnx"
    }

    # Build runtime image
    $deployImageName = "belt-control-app:ubuntu24"
    docker build -t $deployImageName $deployContext

    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Runtime image built successfully" -ForegroundColor Green

        # Export image
        Write-Host "`nExporting Docker image..." -ForegroundColor Yellow
        $exportFile = "$ProjectRoot/belt-control-ubuntu24.tar"
        docker save -o $exportFile $deployImageName

        $fileSize = (Get-Item $exportFile).Length / 1MB
        Write-Host "Image size: $([Math]::Round($fileSize, 2)) MB" -ForegroundColor Cyan

        # Deploy to device
        Write-Host "`nDeploying to device $TargetDevice..." -ForegroundColor Yellow
        scp $exportFile "pi@${TargetDevice}:/tmp/"

        if ($LASTEXITCODE -eq 0) {
            # Deploy script
            $deployCommands = @'
#!/bin/bash
echo "Loading Docker image..."
sudo docker load -i /tmp/belt-control-ubuntu24.tar
sudo docker stop belt-control 2>/dev/null
sudo docker rm belt-control 2>/dev/null
sudo docker run -d --name belt-control --restart unless-stopped --privileged -v /dev:/dev belt-control-app:ubuntu24
sudo docker ps | grep belt-control
rm /tmp/belt-control-ubuntu24.tar
echo "Deployment complete!"
'@

            $deployCommands | ssh "pi@${TargetDevice}" "bash -s"

            if ($LASTEXITCODE -eq 0) {
                Write-Host "`n[OK] Deployment successful!" -ForegroundColor Green
                Write-Host "View logs: ssh pi@$TargetDevice 'sudo docker logs -f belt-control'" -ForegroundColor Cyan
            }
        }

        # Cleanup
        Remove-Item $exportFile -ErrorAction SilentlyContinue
    }

    # Cleanup deployment context
    Remove-Item -Recurse -Force $deployContext -ErrorAction SilentlyContinue
}

Write-Host "`n[OK] All tasks completed!" -ForegroundColor Green