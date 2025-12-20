# RK3588 Docker 一键部署方案

## 方案优势

✅ **完全容器化** - 所有依赖打包在 Docker 镜像中
✅ **不污染系统** - 工控机只需要安装 Docker
✅ **一键部署** - 自动化脚本完成所有操作
✅ **批量生产** - 同一个镜像可快速部署到多台设备
✅ **易于维护** - 版本管理、回滚、更新都很简单
✅ **资源隔离** - 容器独立运行，不影响其他服务

---

## 快速开始

### 方式一：完全自动化（推荐）

在开发机上运行一键部署脚本：

```batch
cd docker\rk3588
deploy-all.bat
```

这个脚本会自动完成：
1. 构建运行时 Docker 镜像
2. 保存镜像为 tar 文件
3. 传输到工控机
4. 在工控机上自动部署和启动

---

### 方式二：分步执行

#### 步骤 1：构建运行时镜像（开发机）

```batch
cd docker\rk3588
build-runtime.bat
```

这会创建一个约 500MB 的运行时镜像，包含：
- 编译好的 belt_control_system 可执行文件
- Qt6 运行时库
- PJSIP 库
- Sherpa-ONNX RKNN 版本
- 所有系统依赖库
- TTS 模型和音频文件

#### 步骤 2：保存镜像到文件

```batch
docker save belt-control-rk3588:runtime -o belt-control-runtime.tar
```

#### 步骤 3：传输到工控机

```batch
scp belt-control-runtime.tar pi@192.168.10.170:/tmp/
scp deploy.sh pi@192.168.10.170:/tmp/
scp docker-compose.yml pi@192.168.10.170:/tmp/
```

#### 步骤 4：在工控机上部署

```bash
ssh pi@192.168.10.170
chmod +x /tmp/deploy.sh
sudo /tmp/deploy.sh
```

---

## 工控机环境要求

### 最小要求

- **操作系统**: Debian 11 (bullseye) ARM64
- **Docker**: 20.10+ （脚本会自动安装）
- **磁盘空间**: 至少 2GB 可用空间
- **内存**: 至少 1GB
- **权限**: sudo 权限

### 安装 Docker（如果未安装）

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

安装 Docker Compose:

```bash
sudo apt-get update
sudo apt-get install -y docker-compose
```

---

## 使用说明

### 启动服务

```bash
cd /opt/belt_control
docker-compose up -d
```

### 查看状态

```bash
docker-compose ps
```

### 查看日志

```bash
# 实时日志
docker-compose logs -f

# 最近100行日志
docker-compose logs --tail=100
```

### 停止服务

```bash
docker-compose down
```

### 重启服务

```bash
docker-compose restart
```

### 更新镜像

```bash
# 1. 在开发机上构建新镜像
docker save belt-control-rk3588:runtime -o belt-control-runtime-v2.tar

# 2. 传输到工控机
scp belt-control-runtime-v2.tar pi@192.168.10.170:/tmp/

# 3. 加载新镜像
ssh pi@192.168.10.170
docker load -i /tmp/belt-control-runtime-v2.tar

# 4. 重启容器
cd /opt/belt_control
docker-compose down
docker-compose up -d
```

---

## 批量部署到多台工控机

### 方式一：使用脚本批量部署

创建工控机列表文件 `machines.txt`:

```
192.168.10.170
192.168.10.171
192.168.10.172
```

批量部署脚本:

```bash
#!/bin/bash
IMAGE_FILE="belt-control-runtime.tar"

while read -r IP; do
    echo "部署到 $IP ..."

    # 传输文件
    scp $IMAGE_FILE deploy.sh docker-compose.yml pi@$IP:/tmp/

    # 执行部署
    ssh pi@$IP "chmod +x /tmp/deploy.sh && sudo /tmp/deploy.sh"

    echo "✅ $IP 部署完成"
done < machines.txt
```

### 方式二：U盘离线部署

1. 将 `belt-control-runtime.tar` 复制到 U盘
2. 在工控机上：
   ```bash
   # 挂载 U盘
   sudo mount /dev/sda1 /mnt

   # 加载镜像
   docker load -i /mnt/belt-control-runtime.tar

   # 启动服务
   cd /opt/belt_control
   docker-compose up -d
   ```

---

## 配置文件管理

### 默认配置位置

```
/opt/belt_control/
├── config/           # 配置文件（持久化）
│   ├── config.ini   # 主配置文件
│   └── kms.json     # 显示配置
├── data/            # 数据文件（持久化）
│   ├── alarm_history.db
│   └── protection_config.db
└── docker-compose.yml
```

### 修改配置

```bash
cd /opt/belt_control
nano config/config.ini

# 重启服务生效
docker-compose restart
```

### 备份配置和数据

```bash
cd /opt/belt_control
tar -czf backup-$(date +%Y%m%d).tar.gz config/ data/

# 传输到开发机
scp backup-*.tar.gz user@dev-machine:/path/to/backup/
```

---

## 故障排查

### 容器无法启动

```bash
# 查看详细日志
docker-compose logs

# 检查容器状态
docker ps -a

# 进入容器调试
docker-compose exec belt-control bash
```

### 显示问题

检查显示设备:

```bash
# 检查 /dev/dri
ls -la /dev/dri

# 检查 framebuffer
cat /sys/class/graphics/fb0/modes

# 测试 EGL
docker-compose exec belt-control /opt/app/bin/belt_control_system --platform eglfs
```

### 音频问题

```bash
# 检查音频设备
docker-compose exec belt-control aplay -l

# 测试音频
docker-compose exec belt-control speaker-test -t wav -c 2
```

### 网络/SIP 问题

```bash
# 检查网络模式（应该是 host）
docker inspect belt_control_system | grep NetworkMode

# 检查端口监听
netstat -tlnp | grep 5060
```

---

## 性能优化

### GPU 加速

确保 `/dev/dri` 设备可访问：

```bash
# 检查权限
ls -la /dev/dri

# 如果需要，添加用户到 video 组
sudo usermod -aG video $USER
```

### 内存限制

在 `docker-compose.yml` 中添加：

```yaml
services:
  belt-control:
    mem_limit: 512m
    memswap_limit: 1g
```

### CPU 限制

```yaml
services:
  belt-control:
    cpus: '2'
```

---

## 安全建议

1. **限制容器权限**: 如果不需要访问所有硬件，移除 `privileged: true`
2. **使用只读卷**: 对于不需要修改的数据，使用 `:ro` 标记
3. **定期更新**: 定期更新基础镜像和依赖库
4. **日志轮转**: 配置日志大小限制，避免磁盘填满
5. **防火墙**: 配置防火墙规则，只开放必要端口

---

## 监控和维护

### 自动重启

容器配置了 `restart: unless-stopped`，会在：
- 容器崩溃后自动重启
- 系统重启后自动启动
- 手动停止后不会自动启动

### 健康检查

容器配置了健康检查，每30秒检查一次进程状态：

```bash
# 查看健康状态
docker inspect belt_control_system | grep Health -A 10
```

### 资源监控

```bash
# 实时监控
docker stats belt_control_system

# 查看资源使用
docker-compose top
```

---

## 技术支持

- 查看日志: `docker-compose logs -f`
- 进入容器: `docker-compose exec belt-control bash`
- 重启服务: `docker-compose restart`
- 完全重置: `docker-compose down && docker-compose up -d`

---

## 附录：目录结构

```
docker/rk3588/
├── Dockerfile.runtime          # 运行时镜像定义
├── build-runtime.bat           # 构建运行时镜像（Windows）
├── prepare-runtime.sh          # 准备运行时依赖
├── deploy.sh                   # 工控机部署脚本
├── deploy-all.bat              # 一键部署脚本（Windows）
├── docker-compose.yml          # Docker Compose 配置
├── README_DEPLOY.md            # 本文档
└── runtime-libs/               # 运行时依赖库（自动生成）
    ├── bin_arm64/
    │   └── belt_control_system
    ├── *.so*
    ├── tts_models/
    ├── AUDIO/
    └── config.ini.example
```
