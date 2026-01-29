# Docker 安装网络问题解决方案

**问题描述**：设备 192.168.10.185 无法访问 Docker 官方源（download.docker.com）

**错误信息**：
```
curl: (35) OpenSSL SSL_connect: 连接被对方重设 in connection to download.docker.com:443
```

---

## 方案一：检查网络连接

### 1. 测试网络连接

连接到设备：
```bash
ssh linaro@192.168.10.185
```

测试网络：
```bash
# 测试基本网络
ping -c 3 8.8.8.8

# 测试 DNS 解析
ping -c 3 www.baidu.com

# 测试 Docker 官方源
curl -I https://download.docker.com

# 测试 HTTPS 连接
curl -v https://www.google.com
```

### 2. 检查防火墙和代理

```bash
# 检查防火墙状态
sudo ufw status

# 检查代理设置
env | grep -i proxy

# 检查 DNS 配置
cat /etc/resolv.conf
```

---

## 方案二：配置 HTTP 代理（如果有代理服务器）

### 临时配置

```bash
export http_proxy="http://proxy_server:port"
export https_proxy="http://proxy_server:port"
export no_proxy="localhost,127.0.0.1"
```

### 永久配置

编辑 `/etc/environment`：
```bash
sudo nano /etc/environment
```

添加：
```
http_proxy="http://proxy_server:port"
https_proxy="http://proxy_server:port"
no_proxy="localhost,127.0.0.1"
```

---

## 方案三：使用国内镜像源

### 方法 1: 使用阿里云镜像

```bash
# 下载安装脚本
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 添加阿里云 Docker 源
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 更新并安装
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 方法 2: 使用清华大学镜像

```bash
# 添加清华大学 Docker 源
curl -fsSL https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

---

## 方案四：完全离线安装

### 步骤 1: 在有网络的机器上下载 Docker 包

访问阿里云镜像站：
https://mirrors.aliyun.com/docker-ce/linux/ubuntu/dists/focal/pool/stable/arm64/

下载以下文件（选择最新版本）：
- `containerd.io_1.6.xx_arm64.deb`
- `docker-ce-cli_xx.x.x_arm64.deb`
- `docker-ce_xx.x.x_arm64.deb`
- `docker-buildx-plugin_x.xx.x_arm64.deb`
- `docker-compose-plugin_x.xx.x_arm64.deb`

**推荐版本**（2026-01-29）：
```
containerd.io_1.6.28-1_arm64.deb
docker-ce-cli_25.0.3-1~ubuntu.20.04~focal_arm64.deb
docker-ce_25.0.3-1~ubuntu.20.04~focal_arm64.deb
docker-buildx-plugin_0.12.1-1~ubuntu.20.04~focal_arm64.deb
docker-compose-plugin_2.24.5-1~ubuntu.20.04~focal_arm64.deb
```

### 步骤 2: 传输到设备

```powershell
# 在 Windows 上执行
scp *.deb linaro@192.168.10.185:/tmp/
```

### 步骤 3: 在设备上安装

```bash
ssh linaro@192.168.10.185

cd /tmp

# 按顺序安装
sudo dpkg -i containerd.io_*.deb
sudo dpkg -i docker-ce-cli_*.deb
sudo dpkg -i docker-ce_*.deb
sudo dpkg -i docker-buildx-plugin_*.deb
sudo dpkg -i docker-compose-plugin_*.deb

# 如果有依赖问题，运行
sudo apt --fix-broken install

# 启动服务
sudo systemctl start docker
sudo systemctl enable docker

# 添加用户到 docker 组
sudo usermod -aG docker $USER

# 验证安装
sudo docker --version
sudo docker run hello-world
```

---

## 方案五：使用自动化脚本（国内镜像）

我已经创建了使用国内镜像的安装脚本：

```powershell
.\scripts\2026-01-29\06-install-docker-china-mirror.ps1 192.168.10.185
```

---

## 推荐方案

根据您的网络情况选择：

1. **如果设备可以访问国内网站**：
   - 使用方案三（国内镜像源）
   - 或使用自动化脚本（方案五）

2. **如果设备完全无法访问互联网**：
   - 使用方案四（完全离线安装）

3. **如果有 HTTP 代理**：
   - 使用方案二（配置代理）

---

## 故障排查

### 问题 1: SSL 连接被重置

**可能原因**：
- 防火墙阻止 HTTPS 连接
- DNS 解析问题
- 网络不稳定

**解决方法**：
1. 检查防火墙设置
2. 更换 DNS 服务器（如 8.8.8.8）
3. 使用国内镜像源

### 问题 2: GPG 密钥下载失败

**解决方法**：
```bash
# 跳过 GPG 验证（不推荐，仅用于测试）
sudo apt install -y --allow-unauthenticated docker-ce
```

### 问题 3: 依赖包缺失

**解决方法**：
```bash
# 安装依赖
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common

# 修复依赖
sudo apt --fix-broken install
```

---

## 下一步

1. 选择合适的安装方案
2. 如果需要帮助，请提供：
   - 网络测试结果（ping、curl 输出）
   - 错误信息截图
   - 设备网络配置

---

**文档创建时间**: 2026-01-29
**适用设备**: RK3588 (192.168.10.185)
**系统版本**: Ubuntu 20.04.6 LTS (ARM64)
