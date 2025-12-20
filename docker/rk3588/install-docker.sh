#!/bin/bash
# Docker 环境一键安装脚本（RK3588/ARM64）
# 适用于 Debian/Ubuntu ARM64 系统

set -e

echo "========================================"
echo "Docker 环境自动安装"
echo "========================================"
echo ""

# 检查是否为 root 或有 sudo 权限
if [ "$EUID" -ne 0 ]; then
    if ! command -v sudo &> /dev/null; then
        echo "❌ 需要 root 权限或 sudo，但 sudo 未安装"
        exit 1
    fi
    SUDO="sudo"
else
    SUDO=""
fi

# 检查是否已安装 Docker
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo "✅ Docker 已安装: $DOCKER_VERSION"
    echo ""
    read -p "是否重新安装？(y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "跳过 Docker 安装"
        SKIP_DOCKER=1
    fi
fi

# 安装 Docker
if [ -z "$SKIP_DOCKER" ]; then
    echo "步骤 1/5: 更新软件包列表..."
    $SUDO apt-get update

    echo ""
    echo "步骤 2/5: 安装依赖包..."
    $SUDO apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    echo ""
    echo "步骤 3/5: 添加 Docker 官方 GPG 密钥..."
    $SUDO mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg

    echo ""
    echo "步骤 4/5: 添加 Docker 软件源..."
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
      $(lsb_release -cs) stable" | $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null

    echo ""
    echo "步骤 5/5: 安装 Docker Engine..."
    $SUDO apt-get update
    $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    echo ""
    echo "✅ Docker 安装完成！"
fi

# 配置当前用户权限
echo ""
echo "配置用户权限..."
if [ -n "$SUDO" ]; then
    CURRENT_USER=$USER
    $SUDO usermod -aG docker $CURRENT_USER
    echo "✅ 用户 $CURRENT_USER 已添加到 docker 组"
    echo ""
    echo "⚠️  注意: 需要重新登录才能生效！"
    echo "   或运行: newgrp docker"
fi

# 启动 Docker 服务
echo ""
echo "启动 Docker 服务..."
$SUDO systemctl enable docker
$SUDO systemctl start docker
echo "✅ Docker 服务已启动"

# 测试 Docker
echo ""
echo "测试 Docker 安装..."
if $SUDO docker run --rm hello-world > /dev/null 2>&1; then
    echo "✅ Docker 测试成功！"
else
    echo "⚠️  Docker 测试失败，但安装可能成功"
fi

# 显示版本信息
echo ""
echo "========================================"
echo "安装信息"
echo "========================================"
docker --version
docker compose version
echo ""

# 显示系统信息
echo "系统信息:"
echo "  架构: $(uname -m)"
echo "  内核: $(uname -r)"
echo "  发行版: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo ""

# 显示磁盘空间
echo "磁盘空间:"
df -h / | tail -1 | awk '{print "  可用: " $4 " / 总计: " $2}'
echo ""

echo "========================================"
echo "✅ Docker 环境准备完成！"
echo "========================================"
echo ""
echo "下一步:"
echo "  1. 如果是首次安装，请重新登录或运行: newgrp docker"
echo "  2. 测试 Docker: docker run hello-world"
echo "  3. 准备部署应用"
echo ""
