# Belt Control System - Docker 一键部署指南

## 快速开始

### 前提条件
- ✅ Windows 电脑(用于执行部署脚本)
- ✅ 目标设备: aarch64 架构 + Docker
- ✅ 网络连接: Windows 可以 SSH 连接到目标设备

### 一键部署命令
```powershell
# 交互式部署
.\docker\rk3588\一键部署-完整版.ps1

# 或指定参数
.\docker\rk3588\一键部署-完整版.ps1 -TargetHost "192.168.10.155" -TargetUser "linaro"

# 完全自动化
.\docker\rk3588\一键部署-完整版.ps1 -TargetHost "192.168.10.155" -TargetUser "linaro" -AutoRun
```

### 部署过程
脚本会自动完成以下步骤:
1. ✅ 配置 SSH 免密登录
2. ✅ 检查目标设备环境
3. ✅ 传输应用二进制文件
4. ✅ 传输 RK3588 库文件
5. ✅ 传输 Qt6 库文件
6. ✅ 复制系统库
7. ✅ 创建 Dockerfile
8. ✅ 检查网络并处理基础镜像
9. ✅ 构建 Docker 镜像
10. ✅ 启动容器

---

## 常见问题

### Q: 为什么使用 Docker?
**A:** Docker 实现了完全的环境隔离:
- ✅ **不依赖主机 glibc 版本** - 容器内有自己的 glibc 2.38
- ✅ **不依赖主机系统库** - 容器内安装了所有依赖
- ✅ **任何 aarch64 设备都能运行** - 只要有 Docker
- ✅ **批量生产方便** - 同一个镜像可部署到多台设备

### Q: 设备没有网络怎么办?
**A:** 脚本会自动检测并处理:
1. 如果设备有网络:
   - Docker build 时自动从互联网下载系统依赖
   - 简单快速

2. 如果设备无网络:
   - 需要先导出基础镜像:
   ```powershell
   docker pull arm64v8/debian:bookworm-slim
   docker save arm64v8/debian:bookworm-slim -o docker/rk3588/debian-bookworm-arm64.tar
   ```
   - 脚本会自动传输并加载这个镜像

### Q: 密码提示太多怎么办?
**A:** 脚本会自动配置 SSH 免密登录,只需要第一次输入密码

### Q: 部署需要多长时间?
**A:** 取决于网络速度:
- 有网络设备: 约 10-15 分钟
  - 文件传输: 3-5 分钟
  - Docker 构建: 5-10 分钟
- 无网络设备: 约 5-8 分钟
  - 文件传输: 3-5 分钟
  - Docker 构建: 2-3 分钟(使用预加载的镜像)

### Q: 容器启动失败怎么办?
**A:** 查看日志排查:
```bash
ssh user@host
docker logs belt_control
```

常见问题:
1. 缺少系统库 → 检查 Dockerfile 中的依赖列表
2. 权限不足 → 确认使用了 `--privileged` 参数
3. 端口冲突 → 检查主机是否有程序占用相同端口

---

## 验证部署

### 检查容器状态
```bash
ssh user@host "docker ps | grep belt_control"
```

期望输出:
```
CONTAINER ID   IMAGE                  COMMAND                  CREATED         STATUS         PORTS     NAMES
xxxxx          belt-control:latest   "/opt/app/bin/belt_c…"   2 minutes ago   Up 2 minutes             belt_control
```

### 查看应用日志
```bash
ssh user@host "docker logs -f belt_control"
```

### 停止/重启容器
```bash
# 停止
ssh user@host "docker stop belt_control"

# 启动
ssh user@host "docker start belt_control"

# 重启
ssh user@host "docker restart belt_control"
```

### 进入容器调试
```bash
ssh user@host "docker exec -it belt_control /bin/bash"
```

---

## 更新部署

### 快速更新(仅二进制文件变化)
```powershell
# 1. 只传输新的二进制文件
scp build_rk3588_new/bin_arm64/belt_control_system user@host:/home/user/belt-control-build/

# 2. 重新构建镜像
ssh user@host "cd /home/user/belt-control-build && docker build -t belt-control:latest ."

# 3. 重启容器
ssh user@host "docker stop belt_control && docker rm belt_control && docker run -d --name belt_control --privileged --network host --restart unless-stopped belt-control:latest"
```

### 完整更新(包括库文件变化)
重新运行一键部署脚本即可

---

## 批量部署

### 准备设备列表
创建文件 `devices.txt`:
```
192.168.10.155,linaro,linaro
192.168.10.170,pi,pi
192.168.10.180,root,password
```

### 批量部署脚本
```powershell
$devices = Get-Content devices.txt

foreach ($device in $devices) {
    $parts = $device.Split(',')
    $host = $parts[0]
    $user = $parts[1]

    Write-Host "正在部署到: $user@$host" -ForegroundColor Cyan
    .\docker\rk3588\一键部署-完整版.ps1 -TargetHost $host -TargetUser $user -AutoRun -SkipSSHSetup
    Write-Host "完成: $user@$host`n" -ForegroundColor Green
}
```

---

## 技术细节

### 容器配置
- **基础镜像**: `debian:bookworm-slim` (glibc 2.38)
- **系统依赖**: libpulse, libGLES, libEGL, libfontconfig, 等
- **网络模式**: `--network host` (与主机共享网络)
- **权限**: `--privileged` (需要访问硬件设备)
- **重启策略**: `--restart unless-stopped` (自动重启)
- **显示支持**: `-v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=:0`

### 目录结构
```
/home/user/belt-control-build/
├── belt_control_system          (应用二进制)
├── Dockerfile                   (容器定义)
└── libs/                        (所有依赖库)
    ├── libQt6*.so*             (Qt6 库)
    ├── librknn*.so             (RK3588 库)
    ├── libavcodec*.so          (FFmpeg 库)
    └── ... (共约 470 个文件)
```

### 容器内部结构
```
/opt/app/
├── bin/
│   └── belt_control_system     (应用)
└── lib/
    └── *.so*                    (所有依赖库)
```

---

## 故障排查

### 问题: SSH 连接超时
```powershell
# 检查网络连接
ping 192.168.10.155

# 检查 SSH 服务
ssh user@host "echo OK"
```

### 问题: Docker 命令权限不足
```bash
# 将用户添加到 docker 组
sudo usermod -aG docker $USER

# 重新登录或
newgrp docker
```

### 问题: 磁盘空间不足
```bash
# 检查空间
df -h

# 清理旧镜像
docker system prune -a
```

### 问题: 找不到 belt_control_system
```bash
# 检查构建产物
ls -lh build_rk3588_new/bin_arm64/

# 确认编译成功
# 重新编译: .\build.bat
```

---

## 相关文档
- [DOCKER部署问题与解决方案.md](DOCKER部署问题与解决方案.md) - 详细的问题记录和解决方案
- [deploy-ubuntu-final.ps1](deploy-ubuntu-final.ps1) - 原始部署脚本(手动步骤)
- [一键部署-完整版.ps1](一键部署-完整版.ps1) - 自动化部署脚本

---

## 联系支持
如遇到问题,请提供:
1. 目标设备信息: `uname -a`
2. Docker 版本: `docker --version`
3. 容器日志: `docker logs belt_control`
4. 部署脚本输出

---

**版本**: 1.0
**最后更新**: 2025-12-15
