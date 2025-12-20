# 完整的本地编译、Docker构建、部署工作流程
# 用于持续开发的可重复流程
param(
    [string]$Device = "192.168.10.188",
    [string]$DeployDir = "belt-control-$(Get-Date -Format 'yyyyMMdd-HHmm')",
    [switch]$SkipCompile = $false,
    [switch]$SkipDocker = $false,
    [switch]$SkipDeploy = $false
)

$ErrorActionPreference = "Stop"
$ProjectRoot = "e:/2025/3_gongkongji/belt_control_system"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "完整开发工作流程" -ForegroundColor Cyan
Write-Host "目标设备: $Device" -ForegroundColor Yellow
Write-Host "部署目录: /home/linaro/$DeployDir" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

# Step 1: 本地交叉编译
if (-not $SkipCompile) {
    Write-Host "`n[步骤 1/3] 本地交叉编译..." -ForegroundColor Green

    $compileScript = "$ProjectRoot/build-rk3588.ps1"

    # 创建交叉编译脚本（如果不存在）
    if (-not (Test-Path $compileScript)) {
        Write-Host "  创建交叉编译脚本..." -ForegroundColor Yellow
        @'
# RK3588 ARM64交叉编译脚本
param([int]$Threads = 32)

$ErrorActionPreference = "Stop"
$ProjectRoot = "e:/2025/3_gongkongji/belt_control_system"

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "RK3588 Docker Cross-Compilation" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan

# 检查Docker镜像
$imageName = "belt-control-compiler:rk3588"
$imageExists = docker images -q $imageName
if (-not $imageExists) {
    Write-Error "编译镜像不存在，请先运行 build-compiler-image.ps1"
    exit 1
}

# 运行编译
Write-Host "开始编译 (使用 $Threads 线程)..." -ForegroundColor Yellow

$cmakeCmd = "cmake -DCMAKE_TOOLCHAIN_FILE=/opt/qt-raspi/lib/cmake/Qt6/qt.toolchain.cmake -DQT_CHAINLOAD_TOOLCHAIN_FILE=/workspace/docker/rk3588/toolchain-rk3588.cmake -DCMAKE_BUILD_TYPE=Release -DENABLE_SHERPA_ONNX=ON .."
$makeCmd = "make -j$Threads"
$fullCmd = "$cmakeCmd && $makeCmd"

docker run --rm `
    -v "${ProjectRoot}:/workspace" `
    -v "${ProjectRoot}/docker/rk3588/qt-host:/opt/qt-host:ro" `
    -v "${ProjectRoot}/docker/rk3588/qt-raspi:/opt/qt-raspi:ro" `
    -v "${ProjectRoot}/docker/rk3588/sysroot:/opt/sysroot:ro" `
    -v "${ProjectRoot}/docker/rk3588/rk3588-libs:/opt/rk3588-libs:ro" `
    -e QT_HOST_PATH=/opt/qt-host `
    -e QT_TARGET_PATH=/opt/qt-raspi `
    -e SYSROOT=/opt/sysroot/rk3588-root `
    -w /workspace/build_rk3588 `
    $imageName `
    bash -c "$fullCmd"

if ($LASTEXITCODE -eq 0) {
    $binary = "$ProjectRoot/build_rk3588/bin_arm64/belt_control_system"
    if (Test-Path $binary) {
        $size = (Get-Item $binary).Length / 1MB
        Write-Host "`n✅ 编译成功!" -ForegroundColor Green
        Write-Host "二进制文件: $binary" -ForegroundColor Gray
        Write-Host "文件大小: $([Math]::Round($size, 2)) MB" -ForegroundColor Gray
    }
} else {
    Write-Error "编译失败"
}
'@ | Out-File -Encoding UTF8 $compileScript
    }

    # 运行编译
    & powershell -File $compileScript
    if ($LASTEXITCODE -ne 0) {
        Write-Error "编译失败"
        exit 1
    }
} else {
    Write-Host "`n[步骤 1/3] 跳过编译（使用现有二进制）" -ForegroundColor Yellow
}

# 检查二进制文件
$binaryPath = "$ProjectRoot/build_rk3588/bin_arm64/belt_control_system"
if (-not (Test-Path $binaryPath)) {
    # 尝试其他位置
    $altPaths = @(
        "$ProjectRoot/build_rk3588_new/bin_arm64/belt_control_system",
        "$ProjectRoot/build_rk3588_fixed/bin_arm64/belt_control_system"
    )
    foreach ($path in $altPaths) {
        if (Test-Path $path) {
            $binaryPath = $path
            break
        }
    }
}

if (Test-Path $binaryPath) {
    $size = (Get-Item $binaryPath).Length / 1MB
    Write-Host "`n找到二进制文件: $([Math]::Round($size, 2)) MB" -ForegroundColor Green
} else {
    Write-Error "未找到编译的二进制文件"
    exit 1
}

# Step 2: 构建Docker镜像
if (-not $SkipDocker) {
    Write-Host "`n[步骤 2/3] 构建Docker镜像..." -ForegroundColor Green

    $dockerContext = "$ProjectRoot/docker_deploy_workflow"
    if (Test-Path $dockerContext) {
        Remove-Item -Recurse -Force $dockerContext
    }
    New-Item -ItemType Directory $dockerContext | Out-Null

    # 创建优化的Dockerfile
    Write-Host "  创建Dockerfile..." -ForegroundColor Yellow
    @'
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai

# 安装运行时依赖
RUN apt-get update && apt-get install -y \
    libqt6core6t64 \
    libqt6gui6t64 \
    libqt6widgets6t64 \
    libqt6network6t64 \
    libqt6qml6 \
    libqt6quick6 \
    qml6-module-qtquick \
    qml6-module-qtquick-controls \
    qml6-module-qtquick-window \
    qml6-module-qtquick-layouts \
    qml6-module-qtmultimedia \
    libgles2 \
    libegl1 \
    libasound2 \
    libpulse0 \
    libssl3t64 \
    libstdc++6 \
    fonts-noto-cjk \
    x11-apps \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 复制应用文件
COPY belt_control_system /app/
COPY config /app/config/
COPY libs /app/libs/

# 设置权限
RUN chmod +x /app/belt_control_system

# 创建启动脚本
RUN echo '#!/bin/bash' > /app/start.sh && \
    echo 'export QT_QPA_PLATFORM=${QT_QPA_PLATFORM:-xcb}' >> /app/start.sh && \
    echo 'export DISPLAY=${DISPLAY:-:0}' >> /app/start.sh && \
    echo 'export XDG_RUNTIME_DIR=/tmp' >> /app/start.sh && \
    echo 'export LD_LIBRARY_PATH=/app/libs/sherpa-onnx/lib:$LD_LIBRARY_PATH' >> /app/start.sh && \
    echo 'cd /app' >> /app/start.sh && \
    echo 'exec ./belt_control_system "$@"' >> /app/start.sh && \
    chmod +x /app/start.sh

ENTRYPOINT ["/app/start.sh"]
'@ | Out-File -Encoding UTF8 "$dockerContext/Dockerfile"

    # 复制文件
    Write-Host "  准备文件..." -ForegroundColor Yellow
    Copy-Item $binaryPath "$dockerContext/"

    # 复制配置
    if (Test-Path "$ProjectRoot/config") {
        Copy-Item -Recurse "$ProjectRoot/config" "$dockerContext/"
    } else {
        New-Item -ItemType Directory "$dockerContext/config" | Out-Null
    }

    # 复制库文件
    New-Item -ItemType Directory "$dockerContext/libs" -Force | Out-Null
    if (Test-Path "$ProjectRoot/libs/tts_models") {
        Copy-Item -Recurse "$ProjectRoot/libs/tts_models" "$dockerContext/libs/"
    }
    if (Test-Path "$ProjectRoot/libs/sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared") {
        Copy-Item -Recurse "$ProjectRoot/libs/sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared" "$dockerContext/libs/sherpa-onnx"
    }

    # 使用buildx构建ARM64镜像
    Write-Host "  构建ARM64镜像..." -ForegroundColor Yellow

    # 确保buildx可用
    $buildxExists = docker buildx ls | Select-String "arm-builder"
    if (-not $buildxExists) {
        Write-Host "  创建buildx构建器..." -ForegroundColor Gray
        docker buildx create --name arm-builder --use --platform linux/arm64,linux/amd64
    } else {
        docker buildx use arm-builder
    }

    # 构建并导出镜像
    $imageName = "belt-control:workflow-$(Get-Date -Format 'yyyyMMdd-HHmm')"
    $tarFile = "$ProjectRoot/belt-workflow.tar"

    docker buildx build `
        --platform linux/arm64 `
        -t $imageName `
        --output type=docker,dest=$tarFile `
        $dockerContext

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker镜像构建失败"
        exit 1
    }

    Write-Host "  ✅ Docker镜像构建成功" -ForegroundColor Green

    # 清理构建上下文
    Remove-Item -Recurse -Force $dockerContext
} else {
    Write-Host "`n[步骤 2/3] 跳过Docker构建" -ForegroundColor Yellow
    $tarFile = "$ProjectRoot/belt-workflow.tar"
}

# Step 3: 部署到设备
if (-not $SkipDeploy) {
    Write-Host "`n[步骤 3/3] 部署到设备 $Device..." -ForegroundColor Green

    if (-not (Test-Path $tarFile)) {
        Write-Error "Docker镜像文件不存在: $tarFile"
        exit 1
    }

    # 创建部署目录
    Write-Host "  在设备上创建部署目录..." -ForegroundColor Yellow
    ssh "linaro@${Device}" "mkdir -p /home/linaro/$DeployDir"

    # 传输镜像
    Write-Host "  传输Docker镜像..." -ForegroundColor Yellow
    $fileSize = (Get-Item $tarFile).Length / 1MB
    Write-Host "  镜像大小: $([Math]::Round($fileSize, 2)) MB" -ForegroundColor Gray

    scp $tarFile "linaro@${Device}:/home/linaro/$DeployDir/"

    if ($LASTEXITCODE -ne 0) {
        Write-Error "镜像传输失败"
        exit 1
    }

    # 创建运行脚本
    Write-Host "  创建运行脚本..." -ForegroundColor Yellow
    $runScript = @"
#!/bin/bash
# Belt Control System - 工作流部署
# 位置: /home/linaro/$DeployDir
# 生成时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

echo "==========================================="
echo "Belt Control System - Workflow Deployment"
echo "==========================================="

# 加载Docker镜像
echo "加载Docker镜像..."
sudo docker load -i /home/linaro/$DeployDir/belt-workflow.tar

# 获取镜像ID
IMAGE_ID=\$(sudo docker images --format "{{.Repository}}:{{.Tag}}" | grep belt-control:workflow | head -1)
echo "使用镜像: \$IMAGE_ID"

# 停止旧容器
echo "停止旧容器..."
sudo docker stop belt-control-app 2>/dev/null || true
sudo docker rm belt-control-app 2>/dev/null || true

# 启动新容器
echo "启动新容器..."
xhost +local:docker 2>/dev/null || true

sudo docker run -d \
    --name belt-control-app \
    --restart unless-stopped \
    --privileged \
    -e DISPLAY=:0 \
    -e QT_QPA_PLATFORM=xcb \
    -e XDG_RUNTIME_DIR=/tmp \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    -v /dev:/dev \
    -v /sys:/sys \
    -v /run/udev:/run/udev:ro \
    \$IMAGE_ID

echo ""
echo "✅ 容器已启动!"
echo ""
echo "常用命令:"
echo "  查看日志: sudo docker logs -f belt-control-app"
echo "  停止容器: sudo docker stop belt-control-app"
echo "  重启容器: sudo docker restart belt-control-app"
echo "  进入容器: sudo docker exec -it belt-control-app bash"
"@

    # 保存运行脚本到本地临时文件
    $tempScript = "$ProjectRoot/temp_run.sh"
    $runScript | Out-File -Encoding UTF8 $tempScript

    # 传输运行脚本
    scp $tempScript "linaro@${Device}:/home/linaro/$DeployDir/run.sh"
    ssh "linaro@${Device}" "chmod +x /home/linaro/$DeployDir/run.sh"

    # 删除临时文件
    Remove-Item $tempScript

    # 在设备上运行
    Write-Host "`n  在设备上部署..." -ForegroundColor Yellow
    ssh "linaro@${Device}" "/home/linaro/$DeployDir/run.sh"

    # 清理本地镜像文件
    Remove-Item $tarFile -ErrorAction SilentlyContinue

    Write-Host "`n✅ 部署成功!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "部署位置: linaro@${Device}:/home/linaro/$DeployDir" -ForegroundColor Cyan
    Write-Host "运行脚本: /home/linaro/$DeployDir/run.sh" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "`n实用命令:" -ForegroundColor Yellow
    Write-Host "  查看日志: ssh linaro@$Device 'sudo docker logs -f belt-control-app'" -ForegroundColor Gray
    Write-Host "  进入容器: ssh linaro@$Device 'sudo docker exec -it belt-control-app bash'" -ForegroundColor Gray
    Write-Host "  停止容器: ssh linaro@$Device 'sudo docker stop belt-control-app'" -ForegroundColor Gray
    Write-Host "  重启容器: ssh linaro@$Device 'sudo docker restart belt-control-app'" -ForegroundColor Gray
} else {
    Write-Host "`n[步骤 3/3] 跳过部署" -ForegroundColor Yellow
}

Write-Host "`n✨ 工作流程完成!" -ForegroundColor Green
Write-Host "使用参数说明:" -ForegroundColor Cyan
Write-Host "  -SkipCompile  跳过编译步骤" -ForegroundColor Gray
Write-Host "  -SkipDocker   跳过Docker构建" -ForegroundColor Gray
Write-Host "  -SkipDeploy   跳过部署步骤" -ForegroundColor Gray
Write-Host "  -Device       指定目标设备IP" -ForegroundColor Gray
Write-Host "  -DeployDir    指定部署目录名" -ForegroundColor Gray