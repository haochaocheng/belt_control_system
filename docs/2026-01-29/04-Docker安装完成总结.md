# Docker 安装完成总结

**设备**: 192.168.10.185 (linaro)
**完成时间**: 2026-01-29
**Docker 版本**: 28.1.1
**Docker Compose 版本**: v2.35.1

---

## 安装过程

### 问题诊断

1. **初次安装失败原因**：
   - APT 源文件中有多余的引号（`"deb` 而不是 `deb`）
   - GPG 密钥未正确添加

2. **解决方案**：
   - 修复 APT 源文件格式
   - 重新添加 GPG 密钥
   - 使用阿里云镜像源

### 成功安装步骤

```bash
# 1. 修复 APT 源
echo 'deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu focal stable' | sudo tee /etc/apt/sources.list.d/docker.list

# 2. 重新添加 GPG 密钥
sudo rm -f /etc/apt/keyrings/docker.gpg
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 3. 更新 APT 缓存
sudo apt update

# 4. 安装 Docker
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 5. 启动服务
sudo systemctl start docker
sudo systemctl enable docker

# 6. 添加用户到 docker 组
sudo usermod -aG docker linaro

# 7. 配置镜像加速
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.ccs.tencentyun.com"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

# 8. 重启 Docker
sudo systemctl daemon-reload
sudo systemctl restart docker
```

---

## 安装结果

### ✅ 已安装的组件

- **Docker Engine**: 28.1.1
- **Docker Compose**: v2.35.1
- **Docker Buildx Plugin**: 0.23.0
- **Containerd**: 1.7.27

### ✅ 已配置的功能

1. **镜像加速器**：
   - 中国科技大学镜像：https://docker.mirrors.ustc.edu.cn
   - 网易镜像：https://hub-mirror.c.163.com
   - 腾讯云镜像：https://mirror.ccs.tencentyun.com

2. **日志管理**：
   - 日志驱动：json-file
   - 单个日志文件最大：10MB
   - 保留日志文件数：3 个

3. **用户权限**：
   - 用户 `linaro` 已添加到 `docker` 组

---

## 下一步操作

### 1. 重新登录以激活 docker 组权限

```bash
# 方法 1: 注销并重新登录
exit
ssh linaro@192.168.10.185

# 方法 2: 在当前会话中激活（临时）
newgrp docker
```

### 2. 验证无需 sudo 即可使用 docker

```bash
# 检查版本
docker --version
docker compose version

# 查看运行中的容器
docker ps

# 查看镜像列表
docker images

# 测试运行容器
docker run hello-world
```

### 3. 常用 Docker 命令

#### 镜像管理
```bash
# 搜索镜像
docker search ubuntu

# 拉取镜像
docker pull ubuntu:20.04

# 查看本地镜像
docker images

# 删除镜像
docker rmi ubuntu:20.04
```

#### 容器管理
```bash
# 运行容器（交互式）
docker run -it ubuntu:20.04 bash

# 运行容器（后台）
docker run -d --name my-nginx nginx

# 查看运行中的容器
docker ps

# 查看所有容器（包括停止的）
docker ps -a

# 停止容器
docker stop my-nginx

# 启动容器
docker start my-nginx

# 删除容器
docker rm my-nginx

# 查看容器日志
docker logs my-nginx

# 进入运行中的容器
docker exec -it my-nginx bash
```

#### Docker Compose
```bash
# 启动服务
docker compose up -d

# 停止服务
docker compose down

# 查看服务状态
docker compose ps

# 查看日志
docker compose logs -f
```

### 4. 测试 Docker 功能

```bash
# 测试 1: 运行 hello-world
docker run hello-world

# 测试 2: 运行 Ubuntu 容器
docker run -it ubuntu:20.04 bash

# 测试 3: 运行 Nginx 服务器
docker run -d -p 8080:80 --name test-nginx nginx
curl http://localhost:8080
docker stop test-nginx
docker rm test-nginx
```

---

## 故障排查

### 问题 1: 无法拉取镜像

**症状**：
```
Error response from daemon: Get "https://registry-1.docker.io/v2/": context deadline exceeded
```

**解决方案**：
- 已配置镜像加速器，应该可以正常拉取
- 如果仍然失败，检查网络连接：`ping docker.mirrors.ustc.edu.cn`

### 问题 2: 权限被拒绝

**症状**：
```
permission denied while trying to connect to the Docker daemon socket
```

**解决方案**：
```bash
# 确认用户在 docker 组中
groups

# 如果不在，添加并重新登录
sudo usermod -aG docker $USER
exit
# 重新登录
```

### 问题 3: Docker 服务未运行

**症状**：
```
Cannot connect to the Docker daemon
```

**解决方案**：
```bash
# 检查服务状态
sudo systemctl status docker

# 启动服务
sudo systemctl start docker

# 查看日志
sudo journalctl -u docker -n 50
```

---

## 相关文档

1. **安装指南**：
   - [docs/2026-01-29/02-Docker安装指南.md](02-Docker安装指南.md)

2. **网络问题解决方案**：
   - [docs/2026-01-29/03-Docker安装网络问题解决方案.md](03-Docker安装网络问题解决方案.md)

3. **自动化脚本**：
   - `scripts/2026-01-29/06-install-docker-china-mirror.ps1` - 国内镜像源安装
   - `scripts/2026-01-29/07-install-docker-verbose.ps1` - 详细版本安装
   - `scripts/2026-01-29/08-diagnose-docker.ps1` - 诊断脚本

---

## 总结

✅ **Docker 已成功安装并配置完成**

- 使用阿里云镜像源安装
- 配置了国内镜像加速器
- 用户权限已配置
- 服务已启动并设置开机自启

**下一步**：
1. 重新登录以激活 docker 组权限
2. 运行 `docker run hello-world` 测试
3. 开始使用 Docker 部署应用

---

**文档创建时间**: 2026-01-29
**安装人员**: Claude (AI Assistant)
**文档版本**: v1.0
