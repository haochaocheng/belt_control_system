# Docker 部署问题与解决方案

## 目标
实现 belt_control_system 的 Docker 一键部署,使得:
- **不依赖底层系统版本**
- **任何 aarch64 架构设备都能运行**
- **所有依赖都在容器内**
- **批量生产方便**

## 遇到的问题及解决方案

### 问题1: SSH密码频繁弹窗 ✅已解决
**现象**: 每次 scp/ssh 都弹出 Git for Windows 密码输入窗口

**原因**: 没有配置 SSH 密钥免密登录

**解决方案**:
```powershell
# 生成 SSH 密钥(如果不存在)
ssh-keygen -t rsa -b 2048 -f "$env:USERPROFILE\.ssh\id_rsa" -N '""'

# 上传公钥到目标设备
Get-Content "$env:USERPROFILE\.ssh\id_rsa.pub" | ssh user@host 'mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && chmod 700 ~/.ssh'
```

**测试**: `ssh user@host "echo 'Success!'"` 不需要密码

---

### 问题2: GLIBC 版本不匹配 ✅已解决
**现象**:
```
error while loading shared libraries: libavutil.so.56: version `GLIBC_2.38' not found
```

**原因**:
- 应用在 Windows Docker (Debian Bookworm, glibc 2.38) 中编译
- 目标设备 Ubuntu 20.04 只有 glibc 2.31
- 直接运行会版本不匹配

**解决方案**:
使用 Docker 容器隔离 glibc 版本:
- 容器使用 `debian:bookworm-slim` 作为基础镜像
- 容器内有 glibc 2.38,与应用编译环境匹配
- 不依赖主机系统的 glibc 版本

**关键点**: 这正是 Docker 的核心价值 - **环境隔离**

---

### 问题3: Docker 无法访问互联网 ⚠️设备相关
**现象**:
```
failed to do request: Head "https://registry-1.docker.io/...": i/o timeout
```

**原因**: 设备无法访问 Docker Hub 或互联网

**解决方案**:
1. **方案A - 离线镜像传输**(适用于完全离线环境):
```powershell
# 在有网络的机器上导出基础镜像
docker pull arm64v8/debian:bookworm-slim
docker save arm64v8/debian:bookworm-slim -o debian-bookworm-arm64.tar

# 传输到目标设备
scp debian-bookworm-arm64.tar user@host:/tmp/

# 在目标设备加载镜像
docker load -i /tmp/debian-bookworm-arm64.tar
docker tag arm64v8/debian:bookworm-slim debian:bookworm-slim
```

2. **方案B - 配置镜像源**(适用于有内网镜像):
```bash
# 配置 Docker 镜像加速器
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": ["https://your-mirror.com"]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
```

---

### 问题4: 缺少系统依赖库 ✅已解决
**现象**:
```
error while loading shared libraries: libpulse.so.0: cannot open shared object file
error while loading shared libraries: libGLESv2.so.2: cannot open shared object file
... (等多个库)
```

**原因**: Debian Bookworm 最小镜像不包含这些运行时库

**解决方案**:
在 Dockerfile 中安装所需的系统库:
```dockerfile
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpulse0 \
    libgles2 \
    libegl1 \
    libfontconfig1 \
    libglib2.0-0 \
    libxkbcommon0 \
    libpng16-16 \
    libharfbuzz0b \
    libfreetype6 \
    libicu67 \
    libpcre2-16-0 \
    libbrotli1 \
    libdbus-1-3 \
    libx11-6 \
    libx11-xcb1 \
    libxcb1 \
    && rm -rf /var/lib/apt/lists/*
```

**注意**: 如果设备无法访问互联网,需要从 sysroot 手动复制这些库

---

### 问题5: 符号链接传输失败 ✅已解决
**现象**:
```
scp: local stat "librknn_api.so": Too many levels of symbolic links
```

**原因**: Windows 不能正确处理某些 Linux 符号链接(特别是循环引用)

**解决方案**:
在传输脚本中过滤掉符号链接:
```powershell
$libFiles = Get-ChildItem -Path "$LibDir" -File | Where-Object {
    ($_.Extension -match "\.so" -or $_.Name -match "\.so\.") -and
    (-not $_.LinkType)  # 排除符号链接
}
```

---

## 最终部署方案

### 架构设计
```
[Windows 编译环境]
    ├─ build_rk3588_new/bin_arm64/belt_control_system (二进制)
    ├─ docker/rk3588/rk3588-libs/ (RK3588 硬件库)
    ├─ docker/rk3588/qt-raspi/ (Qt6 库)
    └─ docker/rk3588/sysroot/ (系统库备份)
           ↓ 传输
[目标 aarch64 设备]
    ├─ /home/user/belt-control-build/
    │   ├─ belt_control_system
    │   ├─ libs/*.so* (所有依赖库)
    │   └─ Dockerfile
    ↓ docker build
[Docker 容器]
    ├─ debian:bookworm-slim (glibc 2.38)
    ├─ 系统依赖库(通过 apt-get 安装)
    └─ /opt/app/
        ├─ bin/belt_control_system
        └─ lib/*.so* (应用库)
```

### 部署流程
1. **SSH 免密配置** (首次)
2. **传输二进制文件**
3. **传输 RK3588 库** (103个)
4. **传输 Qt6 库** (354个)
5. **传输系统库** (可选,如设备无网络)
6. **传输 Dockerfile**
7. **传输 Debian 基础镜像** (可选,如设备无网络)
8. **构建 Docker 镜像**
9. **启动容器**

---

## 一键部署脚本

### 完整自动化脚本: [deploy-ubuntu-final.ps1](deploy-ubuntu-final.ps1)

关键特性:
- ✅ SSH 免密登录,无密码提示
- ✅ 逐文件传输,避免符号链接问题
- ✅ 自动检测并传输所有依赖
- ✅ 可选自动构建和启动
- ✅ 详细进度显示

执行方式:
```powershell
.\docker\rk3588\deploy-ubuntu-final.ps1
```

---

## 不同设备的兼容性

### ✅ 已验证设备
1. **Ubuntu 20.04.6 LTS (aarch64)**
   - IP: 192.168.10.155
   - User: linaro
   - 特点: 有网络访问
   - 状态: ✅ 部署成功

### ⚠️ 部分验证设备
2. **NanoPi-R6C (Debian 11 Bullseye)**
   - IP: 192.168.10.170
   - User: pi
   - 问题: Docker devicemapper 存储驱动问题
   - 状态: 🔄 待解决

### 通用要求
- ✅ aarch64 架构
- ✅ Docker 已安装
- ✅ 存储空间 > 2GB
- ⚠️ 建议有网络访问(用于下载系统依赖)

---

## 故障排查

### 容器启动失败,持续 Restarting
**检查方法**:
```bash
docker logs belt_control 2>&1 | tail -20
```

**常见原因**:
1. 缺少依赖库 → 在 Dockerfile 中添加
2. 权限问题 → 使用 `--privileged` 参数
3. glibc 版本 → 确保容器使用 debian:bookworm-slim

### 库文件找不到
**检查方法**:
```bash
docker run --rm -v /path/to/build:/app belt-control:latest ldd /app/belt_control_system | grep "not found"
```

**解决方法**:
1. 检查 LD_LIBRARY_PATH 是否正确
2. 确认库文件已复制到容器
3. 检查库的符号链接

### Docker build 网络超时
**快速解决**:
```bash
# 使用离线基础镜像
docker load -i debian-bookworm-arm64.tar

# 或配置镜像加速
sudo vim /etc/docker/daemon.json
```

---

## 未来优化方向

1. **减小镜像体积**
   - 使用多阶段构建
   - 移除不必要的系统库
   - 压缩层数

2. **提升部署速度**
   - 预构建完整镜像
   - 使用 Docker save/load 传输
   - 增量更新机制

3. **增强健壮性**
   - 自动检测设备网络状态
   - 智能选择在线/离线部署
   - 自动回滚失败部署

4. **批量部署**
   - 支持多设备并行部署
   - 统一配置管理
   - 部署状态监控

---

## 总结

通过 Docker 容器化部署,成功实现了:
- ✅ **环境隔离**: 不受主机 glibc 版本影响
- ✅ **依赖完整**: 所有库都在容器内
- ✅ **跨设备兼容**: 任何 aarch64 + Docker 环境都能运行
- ✅ **易于管理**: 一键部署,一键启动

这正是 Docker 的核心价值:**Build once, run anywhere**
