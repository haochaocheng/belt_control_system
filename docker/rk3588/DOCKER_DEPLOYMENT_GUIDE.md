# RK3588 Docker 快速部署指南

## 当前状态

✅ **已完成**:
- 本地预构建基础镜像: `belt-control-base:prebuilt` (133MB, ARM64, Debian Trixie + GLIBC 2.41)
- 155设备完整镜像: `belt-control:complete` (包含应用+Qt6+系统库)

## 部署方案

### 方案 1: 本地快速构建部署（推荐）

**优势**:
- 完全在本地Windows机器构建，利用快速网络下载依赖
- 无需工控机联网
- 可重复构建，便于更新

**执行步骤**:
```powershell
# 在 Windows PowerShell 中运行
cd e:\2025\3_gongkongji\belt_control_system\docker\rk3588
.\quick-deploy-from-local.ps1
```

**脚本功能**:
1. 使用本地预构建基础镜像 `belt-control-base:prebuilt`
2. 在本机构建完整ARM64应用镜像
3. 导出为tar文件
4. 传输到目标设备（默认170,可修改）
5. 在目标设备加载并测试

**修改目标设备**: 编辑脚本第8行
```powershell
$TargetDevice = "170"  # 改为 "155" 或 "170"
```

---

### 方案 2: 从155导出到170

**优势**:
- 使用155上已验证的镜像
- 无需重新构建
- 快速分发到其他设备

**执行步骤**:
```powershell
# 在 Windows PowerShell 中运行
cd e:\2025\3_gongkongji\belt_control_system\docker\rk3588
.\deploy-from-155-to-170.ps1
```

**脚本功能**:
1. 在155上导出 `belt-control:complete` 镜像
2. 下载到本地Windows机器
3. 上传到170设备
4. 在170上加载并测试

---

## 镜像说明

### 基础镜像: belt-control-base:prebuilt
- 大小: 133MB
- 平台: linux/arm64
- 基础: Debian Trixie (GLIBC 2.41)
- 包含: 73个系统运行时库
  - OpenGL/EGL: libgles2, libegl1, libgl1
  - 音频: libpulse0
  - X11/Wayland: libxkbcommon0, libxcb-*
  - 字体: libfontconfig1, libfreetype6
  - D-Bus: libdbus-1-3

### 完整镜像: belt-control:complete
- 包含内容:
  - 基础镜像的所有系统库
  - 应用程序二进制文件 (8MB)
  - 系统库 (FFmpeg, SDL2, RK3588专用库, 225MB)
  - Qt6完整运行时:
    - lib/ - Qt6核心库
    - plugins/ - 包括xcbglintegrations
    - qml/ - QML运行时模块

### 环境变量配置
```bash
LD_LIBRARY_PATH=/app/libs:/opt/qt6/lib
QT_PLUGIN_PATH=/opt/qt6/plugins
QML2_IMPORT_PATH=/opt/qt6/qml
QT_QPA_PLATFORM=eglfs
QT_QPA_EGLFS_INTEGRATION=eglfs_kms
```

---

## 运行应用

### 测试运行
```bash
# SSH到目标设备
ssh pi@192.168.10.170  # 或 ssh linaro@192.168.10.155

# 测试运行（带日志输出）
docker run --rm --security-opt apparmor=unconfined belt-control:complete

# 或使用本地构建的镜像
docker run --rm --security-opt apparmor=unconfined belt-control:local-build
```

### 持久化运行
```bash
docker run -d \
  --name belt-control-app \
  --restart unless-stopped \
  --security-opt apparmor=unconfined \
  -v /app/config:/app/config \
  -v /app/data:/app/data \
  belt-control:complete
```

### 查看日志
```bash
docker logs -f belt-control-app
```

### 停止和删除
```bash
docker stop belt-control-app
docker rm belt-control-app
```

---

## 关键技术解决方案

### GLIBC版本兼容性
**问题**: 应用需要GLIBC 2.38，但设备系统只有2.31/2.36

**解决**:
- Docker容器拥有独立的文件系统
- 使用Debian Trixie基础镜像（GLIBC 2.41）
- 容器内GLIBC与宿主机GLIBC完全独立
- Linux内核5.10+/6.1+完全支持GLIBC 2.41的系统调用

### 网络下载优化
**问题**: 工控机网络慢，下载Debian包耗时长

**解决**:
- 在本地Windows机器构建ARM64镜像
- 利用本地快速网络下载依赖
- 只传输最终的tar文件到工控机
- 工控机无需任何网络下载

### 离线部署
**实现**:
1. 本地构建完整镜像
2. 导出为tar文件（自包含）
3. 通过scp传输到设备
4. docker load加载即可运行
5. 可分发到任意设备

---

## 故障排查

### 1. 镜像构建失败
```powershell
# 检查基础镜像
docker images belt-control-base:prebuilt

# 重新构建基础镜像
docker buildx build --platform linux/arm64 \
  -f Dockerfile.base-prebuilt \
  -t belt-control-base:prebuilt --load .
```

### 2. 传输失败
```powershell
# 测试SSH连接
ssh pi@192.168.10.170 "echo 'Connected'"

# 手动传输
scp belt-control.tar pi@192.168.10.170:/tmp/
```

### 3. 应用运行错误
```bash
# 检查容器日志
docker logs belt-control-app

# 进入容器调试
docker run -it --rm --entrypoint /bin/bash belt-control:complete

# 检查库依赖
ldd /app/belt_control_system
```

### 4. GLIBC版本检查
```bash
# 容器内GLIBC版本
docker run --rm belt-control:complete ldd --version

# 应该显示: ldd (Debian GLIBC 2.41-12) 2.41
```

---

## 下一步操作

### 测试方案2（推荐先执行）
```powershell
# 从155导出并部署到170
.\deploy-from-155-to-170.ps1
```

### 或测试方案1
```powershell
# 本地构建并部署
.\quick-deploy-from-local.ps1
```

### 验证运行
```bash
# SSH到170
ssh pi@192.168.10.170

# 运行应用
docker run --rm --security-opt apparmor=unconfined belt-control:complete

# 预期: 应用正常启动，无GLIBC错误
```

---

## 文件清单

- `Dockerfile.base-prebuilt` - 预构建基础镜像定义
- `Dockerfile.complete` - 完整应用镜像定义
- `quick-deploy-from-local.ps1` - 本地构建部署脚本
- `deploy-from-155-to-170.ps1` - 从155分发脚本
- `DOCKER_DEPLOYMENT_GUIDE.md` - 本文档

---

## 技术架构

```
本地Windows机器 (快速网络)
    ↓
构建 ARM64 镜像 (Docker Buildx)
    ↓
导出 TAR 文件 (~1.5GB)
    ↓
传输到工控机 (SCP)
    ↓
加载并运行 (Docker)
```

**关键优势**:
- ✅ 一次构建，到处运行
- ✅ 无需工控机联网
- ✅ GLIBC版本独立于宿主机
- ✅ 完全自包含，包含所有依赖
- ✅ 可重复构建和分发

---

**生成时间**: 2025-12-16
**状态**: 两个镜像构建成功，待测试部署
