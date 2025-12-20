# 简化的Docker构建、部署工作流程
# 使用已编译的二进制文件
param(
    [string]$Device = "192.168.10.188",
    [string]$DeployDir = "belt-control-$(Get-Date -Format 'yyyyMMdd-HHmm')",
    [switch]$SkipDocker = $false,
    [switch]$SkipDeploy = $false
)

$ErrorActionPreference = "Stop"
$ProjectRoot = "e:/2025/3_gongkongji/belt_control_system"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "简化部署工作流程" -ForegroundColor Cyan
Write-Host "目标设备: $Device" -ForegroundColor Yellow
Write-Host "部署目录: /home/linaro/$DeployDir" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

# Step 1: 检查二进制文件
Write-Host "`n[步骤 1/3] 检查已编译的二进制文件..." -ForegroundColor Green

$binaryPath = ""
$searchPaths = @(
    "$ProjectRoot/build_rk3588/bin_arm64/belt_control_system",
    "$ProjectRoot/build_rk3588_new/bin_arm64/belt_control_system",
    "$ProjectRoot/build_rk3588_fixed/bin_arm64/belt_control_system"
)

foreach ($path in $searchPaths) {
    if (Test-Path $path) {
        $binaryPath = $path
        break
    }
}

if ($binaryPath -eq "") {
    Write-Error "未找到编译的二进制文件！请先运行 build-ubuntu24-apt.ps1 编译"
    exit 1
}

$size = (Get-Item $binaryPath).Length / 1MB
Write-Host "  找到二进制文件: $binaryPath" -ForegroundColor Green
Write-Host "  文件大小: $([Math]::Round($size, 2)) MB" -ForegroundColor Gray

# Step 2: 构建Docker镜像
if (-not $SkipDocker) {
    Write-Host "`n[步骤 2/3] 构建Docker镜像..." -ForegroundColor Green

    $dockerContext = "$ProjectRoot/docker_deploy_simple"
    if (Test-Path $dockerContext) {
        Remove-Item -Recurse -Force $dockerContext
    }
    New-Item -ItemType Directory $dockerContext | Out-Null

    # 创建Dockerfile
    Write-Host "  创建Dockerfile..." -ForegroundColor Yellow
    $dockerfileContent = @'
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
    fonts-noto-cjk \
    x11-apps \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 复制应用文件
COPY belt_control_system /app/
COPY config.ini /app/config.ini
COPY libs /app/libs/

# 设置权限
RUN chmod +x /app/belt_control_system

# 设置环境变量
ENV QT_QPA_PLATFORM=xcb
ENV DISPLAY=:0
ENV XDG_RUNTIME_DIR=/tmp
ENV LD_LIBRARY_PATH=/app/libs/sherpa-onnx/lib:$LD_LIBRARY_PATH

CMD ["/app/belt_control_system"]
'@
    $dockerfileContent | Out-File -Encoding UTF8 "$dockerContext/Dockerfile"

    # 复制文件
    Write-Host "  准备文件..." -ForegroundColor Yellow
    Copy-Item $binaryPath "$dockerContext/"

    # 复制配置文件
    if (Test-Path "$ProjectRoot/config.ini") {
        Copy-Item "$ProjectRoot/config.ini" "$dockerContext/"
    } else {
        Write-Host "  警告: config.ini 不存在" -ForegroundColor Yellow
        "# 默认配置文件" | Out-File -Encoding UTF8 "$dockerContext/config.ini"
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
        docker buildx create --name arm-builder --use --platform linux/arm64
    } else {
        docker buildx use arm-builder
    }

    # 构建并导出镜像
    $imageName = "belt-control:$(Get-Date -Format 'yyyyMMdd-HHmm')"
    $tarFile = "$ProjectRoot/belt-deploy.tar"

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
    Write-Host "  镜像文件: $tarFile" -ForegroundColor Gray

    # 清理构建上下文
    Remove-Item -Recurse -Force $dockerContext
} else {
    Write-Host "`n[步骤 2/3] 跳过Docker构建" -ForegroundColor Yellow
    $tarFile = "$ProjectRoot/belt-deploy.tar"
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

    # 创建运行脚本（使用单引号避免PowerShell解析）
    Write-Host "  创建运行脚本..." -ForegroundColor Yellow
    $runScriptContent = @'
#!/bin/bash
# Belt Control System - 部署脚本

echo "==========================================="
echo "Belt Control System - Docker Deployment"
echo "==========================================="

# 设置部署目录变量
DEPLOY_DIR="DEPLOY_DIR_PLACEHOLDER"

# 加载Docker镜像
echo "加载Docker镜像..."
sudo docker load -i /home/linaro/${DEPLOY_DIR}/belt-deploy.tar

# 获取镜像名称
IMAGE_NAME=$(sudo docker images --format "{{.Repository}}:{{.Tag}}" | grep belt-control | head -1)
echo "使用镜像: ${IMAGE_NAME}"

# 停止并删除旧容器
echo "停止旧容器..."
sudo docker stop belt-control-app 2>/dev/null
sudo docker rm belt-control-app 2>/dev/null

# 启动新容器
echo "启动新容器..."
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
    ${IMAGE_NAME}

# 检查容器状态
sleep 2
if sudo docker ps | grep -q belt-control-app; then
    echo ""
    echo "✅ 容器启动成功!"
    echo ""
    echo "常用命令:"
    echo "  查看日志: sudo docker logs -f belt-control-app"
    echo "  停止容器: sudo docker stop belt-control-app"
    echo "  进入容器: sudo docker exec -it belt-control-app bash"
else
    echo "❌ 容器启动失败，查看日志："
    sudo docker logs belt-control-app
fi
'@

    # 替换占位符
    $runScriptContent = $runScriptContent -replace "DEPLOY_DIR_PLACEHOLDER", $DeployDir

    # 保存到临时文件
    $tempScript = "$ProjectRoot/temp_run.sh"
    $runScriptContent | Out-File -Encoding UTF8 -NoNewline $tempScript

    # 传输运行脚本
    scp $tempScript "linaro@${Device}:/home/linaro/$DeployDir/run.sh"
    ssh "linaro@${Device}" "chmod +x /home/linaro/$DeployDir/run.sh"

    # 删除临时文件
    Remove-Item $tempScript

    # 在设备上运行
    Write-Host "`n  在设备上部署..." -ForegroundColor Yellow
    ssh "linaro@${Device}" "/home/linaro/$DeployDir/run.sh"

    # 清理本地镜像文件（可选）
    # Remove-Item $tarFile -ErrorAction SilentlyContinue

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
Write-Host "使用说明:" -ForegroundColor Cyan
Write-Host "  .\build-deploy-workflow-simple.ps1              # 完整流程" -ForegroundColor Gray
Write-Host "  .\build-deploy-workflow-simple.ps1 -SkipDocker  # 只部署（使用现有镜像）" -ForegroundColor Gray
Write-Host "  .\build-deploy-workflow-simple.ps1 -SkipDeploy  # 只构建Docker镜像" -ForegroundColor Gray