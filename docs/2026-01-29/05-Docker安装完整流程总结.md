# Docker 安装完整流程总结

**日期**: 2026-01-29
**设备**: 192.168.10.185 (linaro)
**最终状态**: ✅ 安装成功

---

## 一、问题诊断和解决过程

### 1.1 初次安装失败

**问题 1: 网络连接失败**
```
curl: (35) OpenSSL SSL_connect: 连接被对方重设 in connection to download.docker.com:443
```

**原因**: 设备无法访问 Docker 官方源

**解决方案**: 使用国内镜像源（阿里云）

---

**问题 2: APT 源格式错误**
```
E: 软件源列表 /etc/apt/sources.list.d/docker.list 第 1 行中的类别 ""deb" 无法识别
```

**原因**: PowerShell here-string 中的引号嵌套问题，导致 APT 源文件包含多余的引号

**错误内容**:
```
"deb [arch=arm64 ...] https://mirrors.aliyun.com/docker-ce/linux/ubuntu focal stable"
```

**正确内容**:
```
deb [arch=arm64 ...] https://mirrors.aliyun.com/docker-ce/linux/ubuntu focal stable
```

**解决方案**: 使用单引号 here-string，避免引号嵌套

---

**问题 3: GPG 密钥验证失败**
```
W: GPG 错误：https://mirrors.aliyun.com/docker-ce/linux/ubuntu focal InRelease: 由于没有公钥，无法验证下列签名： NO_PUBKEY 7EA0A9C3F273FCD8
```

**原因**: GPG 密钥未正确添加或已损坏

**解决方案**: 删除旧密钥并重新添加

---

### 1.2 最终解决方案

```bash
# 1. 删除旧的 GPG 密钥
sudo rm -f /etc/apt/keyrings/docker.gpg

# 2. 重新添加 GPG 密钥
curl -fsSL https://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# 3. 修复 APT 源文件
echo 'deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] https://mirrors.aliyun.com/docker-ce/linux/ubuntu focal stable' | sudo tee /etc/apt/sources.list.d/docker.list

# 4. 更新 APT 缓存
sudo apt update

# 5. 安装 Docker
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# 6. 启动服务
sudo systemctl start docker
sudo systemctl enable docker

# 7. 添加用户到 docker 组
sudo usermod -aG docker linaro

# 8. 配置镜像加速
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

# 9. 重启 Docker
sudo systemctl daemon-reload
sudo systemctl restart docker
```

---

## 二、脚本修复内容

### 2.1 修复的脚本

**主脚本**: `scripts/2026-01-29/06-install-docker-china-mirror.ps1`

**修复内容**:

1. **GPG 密钥处理**:
   ```powershell
   # 修复前
   $addGpgKey = @"
   sudo mkdir -p /etc/apt/keyrings
   curl -fsSL $($selectedMirror.gpg) | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
   "@

   # 修复后
   $addGpgKey = @"
   sudo rm -f /etc/apt/keyrings/docker.gpg
   sudo mkdir -p /etc/apt/keyrings
   curl -fsSL $($selectedMirror.gpg) | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
   "@
   ```

2. **APT 源配置**:
   ```powershell
   # 修复前（会产生引号嵌套问题）
   $addRepo = @"
   echo \"deb [arch=`$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] $($selectedMirror.repo) `$(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   "@

   # 修复后（使用单引号，硬编码架构和版本）
   $addRepo = @"
   echo 'deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] $($selectedMirror.repo) focal stable' | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
   "@
   ```

3. **新增镜像加速自动配置**:
   ```powershell
   # 步骤 9: 配置镜像加速
   $configureMirror = @'
   sudo mkdir -p /etc/docker
   sudo tee /etc/docker/daemon.json > /dev/null <<'DOCKEREOF'
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
   DOCKEREOF
   sudo systemctl daemon-reload
   sudo systemctl restart docker
   '@
   ssh -i $sshKey "$DeviceUser@$DeviceIp" "bash -c '$configureMirror'"
   ```

4. **增强验证和测试**:
   ```powershell
   # 检查 Docker 版本
   if ($dockerVersion -match "Docker version") {
       Write-Host "  ✅ Docker: $dockerVersion" -ForegroundColor Green
   } else {
       Write-Host "  ❌ Docker 未正确安装" -ForegroundColor Red
   }

   # 测试 Docker
   $helloWorld = ssh -i $sshKey "$DeviceUser@$DeviceIp" "sudo docker run --rm hello-world 2>&1"
   if ($helloWorld -match "Hello from Docker") {
       Write-Host "  ✅ Docker 运行正常！" -ForegroundColor Green
   }
   ```

---

## 三、创建的文档和脚本

### 3.1 文档

1. **[02-Docker安装指南.md](02-Docker安装指南.md)**
   - 三种安装方法
   - 详细步骤说明
   - 常用命令参考

2. **[03-Docker安装网络问题解决方案.md](03-Docker安装网络问题解决方案.md)**
   - 5 种解决方案
   - 网络诊断方法
   - 离线安装指南

3. **[04-Docker安装完成总结.md](04-Docker安装完成总结.md)**
   - 完整安装过程
   - 下一步操作指南
   - 故障排查指南

4. **本文档**: 完整流程总结

### 3.2 脚本

1. **03-install-docker.ps1** - 官方源安装（已修复）
2. **05-install-docker-offline.ps1** - 离线安装
3. **06-install-docker-china-mirror.ps1** - 国内镜像源安装（推荐，已修复）
4. **07-install-docker-verbose.ps1** - 详细版本安装
5. **08-diagnose-docker.ps1** - 诊断工具

---

## 四、使用推荐脚本

### 4.1 一键安装（推荐）

```powershell
.\scripts\2026-01-29\06-install-docker-china-mirror.ps1 192.168.10.185
```

**脚本会自动完成**:
- ✅ 检查设备连接
- ✅ 更新系统包
- ✅ 安装依赖
- ✅ 添加 GPG 密钥（自动删除旧密钥）
- ✅ 配置 APT 源（修复引号问题）
- ✅ 安装 Docker Engine
- ✅ 启动服务
- ✅ 添加用户到 docker 组
- ✅ 配置镜像加速器
- ✅ 验证安装
- ✅ 测试 Docker

### 4.2 选择其他镜像源

```powershell
# 使用清华大学镜像
.\scripts\2026-01-29\06-install-docker-china-mirror.ps1 192.168.10.185 -Mirror tsinghua

# 使用中科大镜像
.\scripts\2026-01-29\06-install-docker-china-mirror.ps1 192.168.10.185 -Mirror ustc
```

---

## 五、安装结果

### 5.1 已安装的组件

- **Docker Engine**: 28.1.1
- **Docker Compose**: v2.35.1
- **Docker Buildx Plugin**: 0.23.0
- **Containerd**: 1.7.27

### 5.2 已配置的功能

1. **镜像加速器**:
   - 中国科技大学: https://docker.mirrors.ustc.edu.cn
   - 网易: https://hub-mirror.c.163.com
   - 腾讯云: https://mirror.ccs.tencentyun.com

2. **日志管理**:
   - 单个日志文件最大: 10MB
   - 保留日志文件数: 3 个

3. **用户权限**:
   - 用户 `linaro` 已添加到 `docker` 组

---

## 六、下一步操作

### 6.1 重新登录

```bash
# 方法 1: 注销并重新登录
exit
ssh linaro@192.168.10.185

# 方法 2: 在当前会话中激活（临时）
newgrp docker
```

### 6.2 验证安装

```bash
# 检查版本
docker --version
docker compose version

# 查看运行中的容器
docker ps

# 测试运行容器
docker run hello-world
```

### 6.3 开始使用

```bash
# 拉取镜像
docker pull ubuntu:20.04

# 运行容器
docker run -it ubuntu:20.04 bash

# 运行服务
docker run -d -p 8080:80 --name my-nginx nginx
```

---

## 七、经验总结

### 7.1 关键问题

1. **PowerShell here-string 中的引号嵌套**
   - 使用单引号 `@'...'@` 避免变量替换
   - 避免在 here-string 中使用 `\"` 转义

2. **命令替换在远程执行**
   - `$(command)` 会在本地 PowerShell 中执行
   - 使用单引号 here-string 让命令在远程执行

3. **GPG 密钥管理**
   - 删除旧密钥再添加新密钥
   - 确保密钥文件权限正确

### 7.2 最佳实践

1. **使用国内镜像源**
   - 阿里云镜像速度快且稳定
   - 避免访问 Docker 官方源的网络问题

2. **自动配置镜像加速**
   - 提高镜像拉取速度
   - 减少网络超时问题

3. **详细的错误检测**
   - 检查每个步骤的执行结果
   - 提供清晰的错误信息

---

## 八、相关资源

### 8.1 文档

- [Docker 官方文档](https://docs.docker.com/)
- [Docker Hub](https://hub.docker.com/)
- [阿里云 Docker 镜像](https://mirrors.aliyun.com/docker-ce/)

### 8.2 本地文档

- `docs/2026-01-29/02-Docker安装指南.md`
- `docs/2026-01-29/03-Docker安装网络问题解决方案.md`
- `docs/2026-01-29/04-Docker安装完成总结.md`

---

**文档创建时间**: 2026-01-29
**作者**: Claude (AI Assistant)
**版本**: v1.0
