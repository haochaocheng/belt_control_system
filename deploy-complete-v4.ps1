# 完整本地编译、构建、部署到设备188
# 在/home/linaro创建新的整洁目录
param(
    [string]$Device = "192.168.10.188",
    [string]$DeployDir = "belt-control-$(Get-Date -Format 'yyyyMMdd')"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "完整构建和部署流程" -ForegroundColor Cyan
Write-Host "目标: $Device:/home/linaro/$DeployDir" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

$ProjectRoot = "e:/2025/3_gongkongji/belt_control_system"

# Step 1: 本地编译（使用已有的编译输出）
Write-Host "`n[1/4] 使用已编译的ARM64二进制..." -ForegroundColor Green
$binaryPath = "$ProjectRoot/build_rk3588_new/bin_arm64/belt_control_system"
if (Test-Path $binaryPath) {
    $size = (Get-Item $binaryPath).Length / 1MB
    Write-Host "  Found: belt_control_system ($([Math]::Round($size, 2)) MB)" -ForegroundColor Gray
} else {
    Write-Host "  ERROR: Binary not found!" -ForegroundColor Red
    exit 1
}

# Step 2: 本地构建Docker镜像
Write-Host "`n[2/4] 构建Docker镜像..." -ForegroundColor Green

$buildContext = "$ProjectRoot/docker_deploy_new"
if (Test-Path $buildContext) { Remove-Item -Recurse -Force $buildContext }
New-Item -ItemType Directory $buildContext | Out-Null

# 创建Dockerfile（基于成功的v3.5-apt配置）
@'
FROM ubuntu:24.04

# 安装运行时依赖（基于成功的配置）
RUN apt-get update && apt-get install -y \
    libqt6core6t64 \
    libqt6gui6t64 \
    libqt6widgets6t64 \
    libqt6network6t64 \
    libqt6qml6 \
    libqt6quick6 \
    qml6-module-qtquick \
    qml6-module-qtquick-controls \
    qml6-module-qtmultimedia \
    libgles2 \
    libegl1 \
    libasound2t64 \
    libpulse0 \
    libstdc++6 \
    fonts-noto-cjk \
    x11-apps \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 复制应用文件
COPY belt_control_system /app/
COPY config /app/config/
COPY libs /app/libs/

RUN chmod +x /app/belt_control_system

# 设置环境变量
ENV QT_QPA_PLATFORM=xcb
ENV DISPLAY=:0
ENV XDG_RUNTIME_DIR=/tmp

CMD ["/app/belt_control_system"]
'@ | Out-File -Encoding UTF8 "$buildContext/Dockerfile"

# 复制文件
Copy-Item $binaryPath "$buildContext/"
if (Test-Path "$ProjectRoot/config") {
    Copy-Item -Recurse "$ProjectRoot/config" "$buildContext/"
} else {
    New-Item -ItemType Directory "$buildContext/config" | Out-Null
}

# 复制库文件
New-Item -ItemType Directory "$buildContext/libs" -Force | Out-Null
if (Test-Path "$ProjectRoot/libs/tts_models") {
    Copy-Item -Recurse "$ProjectRoot/libs/tts_models" "$buildContext/libs/"
}
if (Test-Path "$ProjectRoot/libs/sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared") {
    Copy-Item -Recurse "$ProjectRoot/libs/sherpa-onnx-v1.12.9-rknn-linux-aarch64-shared" "$buildContext/libs/sherpa-onnx"
}

# 使用buildx构建ARM64镜像
Write-Host "  构建ARM64 Docker镜像..." -ForegroundColor Yellow

# 检查buildx
$buildxExists = docker buildx ls | Select-String "arm-builder"
if (-not $buildxExists) {
    Write-Host "  创建buildx构建器..." -ForegroundColor Gray
    docker buildx create --name arm-builder --use --platform linux/arm64,linux/amd64
}

# 构建并导出镜像
docker buildx build --platform linux/arm64 -t belt-control:v4.0 --output type=docker,dest=$ProjectRoot/belt-v4.0.tar $buildContext

if ($LASTEXITCODE -ne 0) {
    # 如果buildx失败，尝试直接打包文件
    Write-Host "  Buildx失败，创建部署包..." -ForegroundColor Yellow
    tar -czf "$ProjectRoot/belt-deploy.tar.gz" -C $buildContext .
}

# Step 3: 传输到设备
Write-Host "`n[3/4] 部署到设备 $Device..." -ForegroundColor Green

# 在设备上创建新目录
Write-Host "  创建部署目录: /home/linaro/$DeployDir" -ForegroundColor Gray
ssh "linaro@${Device}" "mkdir -p /home/linaro/$DeployDir"

# 传输文件
if (Test-Path "$ProjectRoot/belt-v4.0.tar") {
    Write-Host "  传输Docker镜像..." -ForegroundColor Yellow
    scp "$ProjectRoot/belt-v4.0.tar" "linaro@${Device}:/home/linaro/$DeployDir/"

    # 在设备上加载镜像
    ssh "linaro@${Device}" "cd /home/linaro/$DeployDir && sudo docker load -i belt-v4.0.tar"
} elseif (Test-Path "$ProjectRoot/belt-deploy.tar.gz") {
    Write-Host "  传输部署包..." -ForegroundColor Yellow
    scp "$ProjectRoot/belt-deploy.tar.gz" "linaro@${Device}:/home/linaro/$DeployDir/"

    # 在设备上构建
    ssh "linaro@${Device}" @"
cd /home/linaro/$DeployDir
tar -xzf belt-deploy.tar.gz
sudo docker build -t belt-control:v4.0 .
"@
}

# Step 4: 创建运行脚本
Write-Host "`n[4/4] 创建运行脚本..." -ForegroundColor Green

$runScript = @'
#!/bin/bash
# Belt Control System v4.0 - 新部署
# 位置: /home/linaro/DEPLOY_DIR

echo "=========================================="
echo "Belt Control System v4.0"
echo "=========================================="

# 停止旧容器
sudo docker stop belt-control-app 2>/dev/null
sudo docker rm belt-control-app 2>/dev/null

# 启动新容器
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
    belt-control:v4.0

echo "容器已启动！"
echo "查看日志: sudo docker logs -f belt-control-app"
echo "停止容器: sudo docker stop belt-control-app"
'@

$runScript = $runScript -replace "DEPLOY_DIR", $DeployDir
$runScript | Out-File -Encoding UTF8 "$buildContext/run.sh"

# 传输运行脚本
scp "$buildContext/run.sh" "linaro@${Device}:/home/linaro/$DeployDir/"
ssh "linaro@${Device}" "chmod +x /home/linaro/$DeployDir/run.sh"

# 运行应用
Write-Host "`n启动应用..." -ForegroundColor Cyan
ssh "linaro@${Device}" "/home/linaro/$DeployDir/run.sh"

# 清理
Remove-Item -Recurse -Force $buildContext -ErrorAction SilentlyContinue
Remove-Item "$ProjectRoot/belt-v4.0.tar" -ErrorAction SilentlyContinue
Remove-Item "$ProjectRoot/belt-deploy.tar.gz" -ErrorAction SilentlyContinue

Write-Host "`n✅ 部署完成！" -ForegroundColor Green
Write-Host "部署位置: linaro@${Device}:/home/linaro/$DeployDir" -ForegroundColor Cyan
Write-Host "运行脚本: /home/linaro/$DeployDir/run.sh" -ForegroundColor Cyan
Write-Host "查看日志: ssh linaro@$Device 'sudo docker logs -f belt-control-app'" -ForegroundColor Gray