# Ubuntu 24.04 构建脚本 - 利用已编译的Qt、库和TTS
param(
    [switch]$BuildOnly = $false,
    [switch]$DeployOnly = $false,
    [string]$TargetDevice = "192.168.10.188"
)

$ErrorActionPreference = "Stop"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Ubuntu 24.04 ARM64 Build System" -ForegroundColor Cyan
Write-Host "利用已编译的Qt、库和TTS" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

$ProjectRoot = "e:/2025/3_gongkongji/belt_control_system"
$DockerFile = "$ProjectRoot/docker/ubuntu24-new/Dockerfile"
$ImageName = "belt-control:ubuntu24-new"

# 检查必要的已编译资源
$requiredPaths = @{
    "Qt Host" = "$ProjectRoot/docker/rk3588/qt-host"
    "Qt Raspi" = "$ProjectRoot/docker/rk3588/qt-raspi"
    "RK3588 Libs" = "$ProjectRoot/docker/rk3588/rk3588-libs"
    "Sherpa-ONNX" = "$ProjectRoot/libs/sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared"
}

Write-Host "`n检查已编译资源..." -ForegroundColor Green
$allFound = $true
foreach ($item in $requiredPaths.GetEnumerator()) {
    if (Test-Path $item.Value) {
        Write-Host "  ✓ $($item.Key): 找到" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $($item.Key): 未找到 - $($item.Value)" -ForegroundColor Red
        $allFound = $false
    }
}

if (-not $allFound) {
    Write-Host "`n缺少必要资源，请确认路径正确" -ForegroundColor Red
    exit 1
}

if (-not $DeployOnly) {
    Write-Host "`n[1/3] 构建Docker编译镜像..." -ForegroundColor Yellow
    docker build -f $DockerFile -t $ImageName $ProjectRoot/docker/ubuntu24-new

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker镜像构建失败"
        exit 1
    }

    Write-Host "`n[2/3] 编译项目..." -ForegroundColor Yellow

    # 创建构建目录
    $buildDir = "$ProjectRoot/build_ubuntu24_arm64"
    if (Test-Path $buildDir) {
        Remove-Item -Recurse -Force $buildDir
    }
    New-Item -ItemType Directory -Path $buildDir | Out-Null

    # 运行编译，挂载所有必要的资源
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
        Write-Error "编译失败"
        exit 1
    }

    # 检查输出
    $outputFile = "$buildDir/belt_control_system"
    if (Test-Path $outputFile) {
        $size = (Get-Item $outputFile).Length / 1MB
        Write-Host "✓ 编译成功: belt_control_system ($([Math]::Round($size, 2)) MB)" -ForegroundColor Green
    } else {
        Write-Error "未找到编译输出"
        exit 1
    }
}

if (-not $BuildOnly) {
    Write-Host "`n[3/3] 构建部署镜像..." -ForegroundColor Yellow

    # 创建运行时Dockerfile
    $runtimeDockerfile = @"
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# 安装运行时依赖
RUN apt-get update && apt-get install -y \
    # Qt6运行时
    libqt6core6t64 \
    libqt6gui6t64 \
    libqt6widgets6t64 \
    libqt6network6t64 \
    libqt6qml6 \
    libqt6quick6 \
    qml6-module-qtquick \
    qml6-module-qtquick-controls \
    # OpenGL
    libgles2-mesa \
    libegl1-mesa \
    # 音频
    libasound2 \
    libpulse0 \
    # 其他
    libssl3t64 \
    fonts-noto-cjk \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 复制应用和资源
COPY belt_control_system /app/
COPY config /app/config/
COPY libs/tts_models /app/libs/tts_models/
COPY libs/sherpa-onnx /app/libs/sherpa-onnx/

RUN chmod +x /app/belt_control_system

ENV QT_QPA_PLATFORM=eglfs
ENV LD_LIBRARY_PATH=/app/libs/sherpa-onnx/lib:${'$'}LD_LIBRARY_PATH

CMD ["/app/belt_control_system"]
"@

    # 创建部署上下文
    $deployContext = "$ProjectRoot/docker_deploy_context"
    if (Test-Path $deployContext) {
        Remove-Item -Recurse -Force $deployContext
    }
    New-Item -ItemType Directory -Path $deployContext | Out-Null

    # 写入Dockerfile
    $runtimeDockerfile | Out-File -Encoding UTF8 "$deployContext/Dockerfile"

    # 复制文件到上下文
    Copy-Item "$buildDir/belt_control_system" "$deployContext/"
    Copy-Item -Recurse "$ProjectRoot/config" "$deployContext/" -ErrorAction SilentlyContinue
    if (Test-Path "$ProjectRoot/libs/tts_models") {
        New-Item -ItemType Directory -Path "$deployContext/libs" -Force | Out-Null
        Copy-Item -Recurse "$ProjectRoot/libs/tts_models" "$deployContext/libs/"
        Copy-Item -Recurse "$ProjectRoot/libs/sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared" "$deployContext/libs/sherpa-onnx"
    }

    # 构建部署镜像
    $deployImageName = "belt-control-app:ubuntu24"
    docker build -t $deployImageName $deployContext

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ 部署镜像构建成功" -ForegroundColor Green

        # 导出镜像
        Write-Host "`n导出Docker镜像..." -ForegroundColor Yellow
        $exportFile = "$ProjectRoot/belt-control-ubuntu24.tar"
        docker save -o $exportFile $deployImageName

        $fileSize = (Get-Item $exportFile).Length / 1MB
        Write-Host "镜像大小: $([Math]::Round($fileSize, 2)) MB" -ForegroundColor Cyan

        # 部署到设备
        Write-Host "`n部署到设备 $TargetDevice..." -ForegroundColor Yellow
        scp $exportFile "pi@${TargetDevice}:/tmp/"

        $deployScript = @"
echo '加载Docker镜像...'
sudo docker load -i /tmp/belt-control-ubuntu24.tar
sudo docker stop belt-control 2>/dev/null || true
sudo docker rm belt-control 2>/dev/null || true
sudo docker run -d --name belt-control --restart unless-stopped --privileged -v /dev:/dev $deployImageName
sudo docker ps | grep belt-control
rm /tmp/belt-control-ubuntu24.tar
"@

        $deployScript | ssh "pi@${TargetDevice}" "bash -s"

        if ($LASTEXITCODE -eq 0) {
            Write-Host "`n✓ 部署成功！" -ForegroundColor Green
            Write-Host "查看日志: ssh pi@$TargetDevice 'sudo docker logs -f belt-control'" -ForegroundColor Cyan
        }

        # 清理
        Remove-Item $exportFile -ErrorAction SilentlyContinue
    }

    # 清理部署上下文
    Remove-Item -Recurse -Force $deployContext -ErrorAction SilentlyContinue
}

Write-Host "`n✓ 所有任务完成！" -ForegroundColor Green