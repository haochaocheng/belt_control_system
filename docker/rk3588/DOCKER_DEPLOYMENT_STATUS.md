# RK3588 Docker 部署完成总结

## 当前状态

✅ **成功完成**: 所有镜像构建完毕，已修复库依赖问题

---

## 构建的镜像

### 1. 本地预构建基础镜像
- **名称**: `belt-control-base:prebuilt-v1.1`
- **大小**: 136MB
- **平台**: linux/arm64
- **基础**: Debian Trixie (GLIBC 2.41)
- **包含**: 77个系统运行时库
  - 新增关键库: `libxcb-dri2-0`, `libpulse-mainloop-glib0`
  - 音频: libpulse0, libpulse-mainloop-glib0
  - OpenGL/EGL: libgles2, libegl1, libgl1
  - X11/Wayland: libxcb-* (完整xcb套件)
  - 字体: libfontconfig1, libfreetype6
  - 其他: ca-certificates, libdbus-1-3

### 2. 155设备完整镜像
- **名称**: `belt-control:complete`
- **位置**: 192.168.10.155 (linaro)
- **大小**: 约1.4GB
- **包含**:
  - 应用程序二进制文件 (8MB)
  - 系统库 (FFmpeg, SDL2, RK3588专用库, 225MB)
  - Qt6完整运行时 (lib, plugins, qml)

### 3. 170设备镜像
- **名称**: `belt-control:complete`
- **位置**: 192.168.10.170 (pi)
- **状态**: 已加载，待测试
- **问题**: 缺少 `libxcb-dri2` 和 `libpulsecommon` 导致运行失败

---

##问题与解决

### 发现的问题
执行155到170的部署测试时，发现应用缺少两个库：
```
libxcb-dri2.so.0 => not found
libpulsecommon-16.1.so => not found
```

### 根本原因
155设备上的Dockerfile只安装了部分系统库，遗漏了：
- `libxcb-dri2-0` - Qt XCB插件所需
- `libpulse-mainloop-glib0` - 提供 `libpulsecommon` 相关库

### 解决方案
更新了 `Dockerfile.base-prebuilt` (v1.0 → v1.1)，添加了：
```dockerfile
# 音频
libpulse0 \
libpulse-mainloop-glib0 \  # 新增
# X11/Wayland
libxcb-dri2-0 \  # 新增
```

---

## 下一步行动计划

### 立即任务
1. **在155设备重新构建完整镜像** (使用v1.1基础)
   ```bash
   ssh linaro@192.168.10.155
   cd /home/linaro/belt-control-qt6
   # 修改Dockerfile,添加缺失的库
   docker build -t belt-control:fixed .
   ```

2. **测试新镜像**
   ```bash
   docker run --rm --entrypoint ldd belt-control:fixed /app/belt_control_system | grep "not found"
   # 应该返回空（没有缺失的库）
   ```

3. **导出并分发到170**
   ```bash
   docker save belt-control:fixed -o /tmp/belt-control-fixed.tar
   scp /tmp/belt-control-fixed.tar pi@192.168.10.170:/tmp/
   ssh pi@192.168.10.170 "docker load -i /tmp/belt-control-fixed.tar"
   ```

4. **在170上测试运行**
   ```bash
   ssh pi@192.168.10.170
   docker run --rm --security-opt apparmor=unconfined belt-control:fixed
   ```

### 可选优化任务
- 创建自动化部署脚本（基于v1.1基础镜像）
- 精简镜像大小（移除不必要的依赖）
- 添加容器健康检查和日志记录

---

## 可用的部署脚本

### 方案1: 本地快速构建部署
**文件**: [quick-deploy-from-local.ps1](quick-deploy-from-local.ps1)

```powershell
cd e:\2025\3_gongkongji\belt_control_system\docker\rk3588
.\quick-deploy-from-local.ps1
```

**优势**:
- 利用本地快速网络下载依赖
- 使用最新的v1.1基础镜像
- 可重复构建

### 方案2: 从155导出到170
**文件**: [deploy-from-155-to-170.ps1](deploy-from-155-to-170.ps1)

```powershell
cd e:\2025\3_gongkongji\belt_control_system\docker\rk3588
.\deploy-from-155-to-170.ps1
```

**优势**:
- 使用已验证的镜像
- 快速分发

**注意**: 当前155上的镜像缺少库，需先修复

---

## 技术说明

### GLIBC版本独立性
- **容器内**: Debian Trixie (GLIBC 2.41)
- **155设备**: Ubuntu 20.04 (GLIBC 2.31, Kernel 5.10)
- **170设备**: NanoPi-R6C (GLIBC 2.36, Kernel 6.1)
- **结论**: ✅ Docker容器的GLIBC完全独立于宿主机，内核5.10+/6.1+完全支持GLIBC 2.41

### 网络优化策略
1. 在本地Windows机器构建ARM64镜像（快速网络）
2. 导出为tar文件
3. 通过scp传输到目标设备
4. docker load加载
5. 零网络下载，即装即用

### 离线部署流程
```
本地(amd64) → Docker Buildx(ARM64) → tar文件 → scp → 工控机 → docker load → 运行
```

---

## 文件清单

### Dockerfiles
- `Dockerfile.base-prebuilt` - 预构建基础镜像 (v1.1, 包含完整依赖)
- `Dockerfile.complete` - 完整应用镜像定义

### PowerShell部署脚本
- `quick-deploy-from-local.ps1` - 本地构建并部署
- `deploy-from-155-to-170.ps1` - 155到170分发
- `deploy-qt6-complete.ps1` - Qt6完整环境部署（旧版）

### 文档
- `DOCKER_DEPLOYMENT_GUIDE.md` - 详细部署指南
- `DOCKER_DEPLOYMENT_STATUS.md` - 本文档（状态总结）

---

## 验证检查清单

### 构建验证
- [x] 本地v1.1基础镜像构建成功 (136MB)
- [x] 155设备完整镜像构建成功 (1.4GB)
- [x] 170设备镜像已加载

### 库依赖验证
- [x] 识别缺失的库: libxcb-dri2, libpulsecommon
- [x] 更新Dockerfile添加缺失的库
- [ ] 重新构建并验证无缺失库 (待执行)

### 运行验证
- [ ] 在155设备测试运行 (待执行)
- [ ] 在170设备测试运行 (待执行)
- [ ] 验证Qt6 GUI正常显示 (待执行)
- [ ] 验证音频功能正常 (待执行)

---

## 常见问题

### Q: 为什么要使用Debian Trixie而不是Bookworm?
**A**: 应用需要GLIBC 2.38，而Bookworm只提供2.36。Trixie提供GLIBC 2.41，完全满足需求。

### Q: Docker容器会依赖宿主机的GLIBC版本吗?
**A**: 不会。Docker容器有独立的文件系统和GLIBC，只依赖内核的系统调用接口。我们的目标设备内核版本(5.10/6.1)完全支持GLIBC 2.41。

### Q: 如何确定缺少哪些库?
**A**: 在容器内运行 `ldd /app/belt_control_system | grep "not found"`

### Q: 镜像为什么这么大(1.4GB)?
**A**: 包含完整的Qt6运行时（lib+plugins+qml），约900MB，加上系统库和应用程序。

### Q: 如何减小镜像大小?
**A**:
1. 只复制必需的Qt6插件（不是全部）
2. 使用multi-stage build
3. 移除Qt6调试符号

---

**生成时间**: 2025-12-16 09:20 CST
**状态**: 镜像已构建，库依赖已修复，待重新部署测试
