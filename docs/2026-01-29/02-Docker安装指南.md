# RK3588 设备 Docker 安装指南

**设备信息**：
- IP: 192.168.10.185
- 用户: linaro
- 系统: Ubuntu 20.04.6 LTS
- 架构: ARM64 (aarch64)
- 内核: 5.10.226

---

## 方法一：使用官方安装脚本（推荐）

### 步骤 1: 连接到设备

```bash
ssh linaro@192.168.10.185
```

### 步骤 2: 更新系统包

```bash
sudo apt update
sudo apt upgrade -y
```

### 步骤 3: 安装必要的依赖

```bash
sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
```

### 步骤 4: 添加 Docker 官方 GPG 密钥

```bash
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
```

### 步骤 5: 添加 Docker APT 源

```bash
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

### 步骤 6: 安装 Docker Engine

```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 步骤 7: 启动 Docker 服务

```bash
sudo systemctl start docker
sudo systemctl enable docker
```

### 步骤 8: 验证安装

```bash
sudo docker --version
sudo docker run hello-world
```

### 步骤 9: 添加用户到 docker 组（可选，避免每次使用 sudo）

```bash
sudo usermod -aG docker $USER
```

**注意**：添加到 docker 组后，需要注销并重新登录才能生效。

```bash
# 注销并重新登录后，测试无需 sudo
docker --version
docker ps
```

---

## 方法二：使用便捷安装脚本

### 一键安装（使用 Docker 官方脚本）

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

### 安装后配置

```bash
# 启动 Docker
sudo systemctl start docker
sudo systemctl enable docker

# 添加用户到 docker 组
sudo usermod -aG docker $USER

# 验证安装
sudo docker --version
```

---

## 方法三：离线安装（如果设备无法访问互联网）

### 步骤 1: 在有网络的机器上下载 Docker 包

访问 Docker 官方下载页面：
https://download.docker.com/linux/ubuntu/dists/focal/pool/stable/arm64/

下载以下文件（ARM64 版本）：
- containerd.io_*.deb
- docker-ce-cli_*.deb
- docker-ce_*.deb
- docker-buildx-plugin_*.deb
- docker-compose-plugin_*.deb

### 步骤 2: 传输到设备

```bash
scp *.deb linaro@192.168.10.185:/tmp/
```

### 步骤 3: 在设备上安装

```bash
ssh linaro@192.168.10.185
cd /tmp
sudo dpkg -i containerd.io_*.deb
sudo dpkg -i docker-ce-cli_*.deb
sudo dpkg -i docker-ce_*.deb
sudo dpkg -i docker-buildx-plugin_*.deb
sudo dpkg -i docker-compose-plugin_*.deb
```

### 步骤 4: 启动服务

```bash
sudo systemctl start docker
sudo systemctl enable docker
```

---

## 安装后配置

### 1. 配置 Docker 镜像加速（可选，提高拉取速度）

创建或编辑 `/etc/docker/daemon.json`：

```bash
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<EOF
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
```

重启 Docker 服务：

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

### 2. 验证配置

```bash
docker info | grep -A 5 "Registry Mirrors"
```

---

## 常用 Docker 命令

### 基本命令

```bash
# 查看 Docker 版本
docker --version

# 查看 Docker 信息
docker info

# 查看运行中的容器
docker ps

# 查看所有容器（包括停止的）
docker ps -a

# 查看镜像列表
docker images

# 拉取镜像
docker pull ubuntu:20.04

# 运行容器
docker run -it ubuntu:20.04 bash

# 停止容器
docker stop <container_id>

# 删除容器
docker rm <container_id>

# 删除镜像
docker rmi <image_id>
```

### Docker Compose 命令

```bash
# 启动服务
docker compose up -d

# 停止服务
docker compose down

# 查看日志
docker compose logs -f

# 重启服务
docker compose restart
```

---

## 故障排查

### 问题 1: Docker 服务无法启动

```bash
# 查看服务状态
sudo systemctl status docker

# 查看日志
sudo journalctl -u docker -n 50
```

### 问题 2: 权限被拒绝

```bash
# 确认用户在 docker 组中
groups $USER

# 如果不在，添加并重新登录
sudo usermod -aG docker $USER
# 注销并重新登录
```

### 问题 3: 无法拉取镜像

```bash
# 检查网络连接
ping -c 3 docker.io

# 检查 DNS 配置
cat /etc/resolv.conf

# 尝试使用镜像加速器（见上面的配置）
```

---

## 卸载 Docker（如果需要）

```bash
# 停止所有容器
docker stop $(docker ps -aq)

# 删除所有容器
docker rm $(docker ps -aq)

# 删除所有镜像
docker rmi $(docker images -q)

# 卸载 Docker 包
sudo apt purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 删除 Docker 数据目录
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd

# 删除配置文件
sudo rm -rf /etc/docker
```

---

## 推荐安装方式

对于 RK3588 设备（192.168.10.185），推荐使用**方法一（官方安装脚本）**：

1. 系统稳定，包管理完善
2. 可以自动处理依赖关系
3. 后续更新方便

如果设备可以访问互联网，直接使用自动化脚本（见下一节）。

---

## 自动化安装脚本

我已经创建了自动化安装脚本：
- `scripts/2026-01-29/03-install-docker.ps1` - 从 Windows 远程安装
- `scripts/2026-01-29/04-install-docker.sh` - 在设备上直接执行

使用方法：

```powershell
# 在 Windows 上执行
.\scripts\2026-01-29\03-install-docker.ps1 192.168.10.185
```

或者在设备上直接执行：

```bash
ssh linaro@192.168.10.185
bash /path/to/install-docker.sh
```

---

**文档创建时间**: 2026-01-29
**适用设备**: RK3588 (192.168.10.185)
**系统版本**: Ubuntu 20.04.6 LTS (ARM64)
