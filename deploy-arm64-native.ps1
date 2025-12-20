# 构建ARM64架构的Docker镜像
param([string]$Device = "192.168.10.188")

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "构建ARM64 Docker镜像并部署" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$root = "e:/2025/3_gongkongji/belt_control_system"
$ctx = "$root/docker_arm64"

# 清理目录
if (Test-Path $ctx) { Remove-Item -Recurse -Force $ctx }
New-Item -ItemType Directory $ctx | Out-Null

# 创建ARM64架构的Dockerfile
@'
# 使用ARM64基础镜像
FROM arm64v8/ubuntu:24.04

RUN apt-get update && apt-get install -y \
    libqt6core6t64 \
    libqt6gui6t64 \
    libqt6widgets6t64 \
    libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY belt_control_system /app/
RUN chmod +x /app/belt_control_system

CMD ["/app/belt_control_system"]
'@ | Out-File -Encoding UTF8 "$ctx/Dockerfile"

# 复制ARM64二进制文件
Copy-Item "$root/build_rk3588_new/bin_arm64/belt_control_system" "$ctx/"

Write-Host "`n方案1: 使用buildx构建ARM64镜像（推荐）" -ForegroundColor Yellow
Write-Host "docker buildx create --use --name arm-builder" -ForegroundColor Gray
Write-Host "docker buildx build --platform linux/arm64 -t belt:arm64 --load $ctx" -ForegroundColor Gray

Write-Host "`n方案2: 直接在设备上构建" -ForegroundColor Yellow

# 打包构建上下文
Write-Host "打包构建文件..." -ForegroundColor Green
tar -czf "$root/docker_arm64.tar.gz" -C $ctx .

# 传输到设备
Write-Host "传输到设备..." -ForegroundColor Green
scp "$root/docker_arm64.tar.gz" "linaro@${Device}:/tmp/"

Write-Host "在设备上构建和运行..." -ForegroundColor Green
ssh "linaro@${Device}" @'
cd /tmp
rm -rf docker_build
mkdir docker_build
cd docker_build
tar -xzf ../docker_arm64.tar.gz
echo "Building Docker image on device..."
sudo docker build -t belt:arm64-native .
echo "Stopping old container..."
sudo docker stop belt 2>/dev/null || true
sudo docker rm belt 2>/dev/null || true
echo "Running new container..."
sudo docker run -d --name belt --privileged -v /dev:/dev belt:arm64-native
echo "Checking status..."
sudo docker ps | grep belt
cd /tmp
rm -rf docker_build docker_arm64.tar.gz
'@

# 清理
Remove-Item "$root/docker_arm64.tar.gz" -ErrorAction SilentlyContinue
Remove-Item -Recurse $ctx -ErrorAction SilentlyContinue

Write-Host "`n完成！" -ForegroundColor Green
Write-Host "查看日志: ssh linaro@$Device 'sudo docker logs -f belt'" -ForegroundColor Cyan