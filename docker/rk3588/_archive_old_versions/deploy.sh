#!/bin/bash
# RK3588 一键部署脚本（在工控机上运行）

set -e

REMOTE_USER="pi"
REMOTE_HOST="192.168.10.170"
IMAGE_FILE="belt-control-runtime.tar"
DEPLOY_DIR="/opt/belt_control"

echo "========================================"
echo "RK3588 皮带控制系统 - 一键部署"
echo "========================================"
echo ""

# 检查 Docker 是否安装
if ! command -v docker &> /dev/null; then
    echo "⚠️  Docker 未安装，正在安装..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    echo "✅ Docker 安装完成"
fi

# 检查 Docker Compose 是否安装
if ! command -v docker-compose &> /dev/null; then
    echo "⚠️  Docker Compose 未安装，正在安装..."
    sudo apt-get update
    sudo apt-get install -y docker-compose
    echo "✅ Docker Compose 安装完成"
fi

echo ""
echo "步骤 1: 创建部署目录..."
sudo mkdir -p "$DEPLOY_DIR"/{config,data,logs}
sudo chown -R $USER:$USER "$DEPLOY_DIR"

echo ""
echo "步骤 2: 加载 Docker 镜像..."
if [ -f "/tmp/$IMAGE_FILE" ]; then
    docker load -i "/tmp/$IMAGE_FILE"
    echo "✅ 镜像加载成功"
else
    echo "❌ 镜像文件不存在: /tmp/$IMAGE_FILE"
    exit 1
fi

echo ""
echo "步骤 3: 复制配置文件..."
if [ ! -f "$DEPLOY_DIR/docker-compose.yml" ]; then
    cat > "$DEPLOY_DIR/docker-compose.yml" <<'EOF'
version: '3.8'

services:
  belt-control:
    image: belt-control-rk3588:runtime
    container_name: belt_control_system
    restart: unless-stopped
    privileged: true
    network_mode: host

    devices:
      - /dev/dri:/dev/dri
      - /dev/video0:/dev/video0
      - /dev/snd:/dev/snd
      - /dev/input:/dev/input
      - /dev/fb0:/dev/fb0

    environment:
      - QT_QPA_PLATFORM=eglfs
      - QT_QPA_EGLFS_INTEGRATION=eglfs_kms
      - QT_QPA_EGLFS_ALWAYS_SET_MODE=1
      - LD_LIBRARY_PATH=/opt/app/lib:/usr/local/lib

    volumes:
      - ./config:/opt/app/config
      - ./data:/opt/app/data
      - /etc/localtime:/etc/localtime:ro

    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
EOF
    echo "✅ docker-compose.yml 已创建"
fi

echo ""
echo "步骤 4: 启动容器..."
cd "$DEPLOY_DIR"
docker-compose down 2>/dev/null || true
docker-compose up -d

echo ""
echo "步骤 5: 检查容器状态..."
sleep 3
docker-compose ps

echo ""
echo "========================================"
echo "✅ 部署完成！"
echo "========================================"
echo ""
echo "容器状态: docker-compose ps"
echo "查看日志: docker-compose logs -f"
echo "停止服务: docker-compose down"
echo "重启服务: docker-compose restart"
echo ""
echo "部署目录: $DEPLOY_DIR"
echo "配置文件: $DEPLOY_DIR/config/"
echo "数据文件: $DEPLOY_DIR/data/"
echo ""
