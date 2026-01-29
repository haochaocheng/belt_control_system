#!/bin/bash
# Docker 自动安装脚本 - RK3588 设备
# 创建时间: 2026-01-29
# 适用系统: Ubuntu 20.04 ARM64

set -e

echo "=== Docker 自动安装脚本 ==="
echo "系统: $(lsb_release -ds)"
echo "架构: $(uname -m)"
echo ""

# 检查是否已安装 Docker
if command -v docker &> /dev/null; then
    echo "⚠️  Docker 已安装"
    docker --version
    read -p "是否要重新安装？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "安装已取消"
        exit 0
    fi
fi

echo "[1/8] 更新系统包..."
sudo apt update

echo ""
echo "[2/8] 安装必要的依赖..."
sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

echo ""
echo "[3/8] 添加 Docker 官方 GPG 密钥..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo ""
echo "[4/8] 添加 Docker APT 源..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo ""
echo "[5/8] 更新 APT 包索引..."
sudo apt update

echo ""
echo "[6/8] 安装 Docker Engine..."
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo ""
echo "[7/8] 启动 Docker 服务..."
sudo systemctl start docker
sudo systemctl enable docker

echo ""
echo "[8/8] 添加当前用户到 docker 组..."
sudo usermod -aG docker $USER

echo ""
echo "=== 安装完成 ==="
echo ""
echo "Docker 版本:"
sudo docker --version
echo ""
echo "Docker Compose 版本:"
sudo docker compose version
echo ""
echo "⚠️  重要提示："
echo "  1. 需要注销并重新登录，才能无需 sudo 使用 docker 命令"
echo "  2. 或者运行: newgrp docker"
echo ""
echo "验证安装:"
echo "  sudo docker run hello-world"
echo ""

# 可选：配置镜像加速
read -p "是否配置 Docker 镜像加速？(y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "配置镜像加速..."
    sudo mkdir -p /etc/docker
    sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
    echo "重启 Docker 服务..."
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    echo "✅ 镜像加速配置完成"
fi

echo ""
echo "🎉 Docker 安装成功！"
