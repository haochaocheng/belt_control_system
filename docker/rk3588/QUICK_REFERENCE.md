# RK3588 快速参考卡

## 🎯 常用命令

### 编译主程序

```batch
docker\rk3588\build-rk3588.bat
```

### 编译多媒体依赖库（PJSIP、FFmpeg等）

```batch
docker\rk3588\build-dependencies.bat
```

### 部署到RK3588

```batch
docker\rk3588\deploy-to-rk3588.bat
```

## 📁 重要目录

| 目录 | 说明 |
|------|------|
| `docker/rk3588/` | Docker构建文件和脚本 |
| `output_rk3588/` | 编译输出（可部署到RK3588） |
| `build_rk3588/` | CMake构建目录 |
| `docker/rk3588/qt-raspi/` | Qt for ARM64（自动解压） |
| `docker/rk3588/sysroot/` | RK3588系统根目录（自动解压） |
| `docker/rk3588/rk3588-libs/` | 多媒体依赖库（编译后生成） |

## 🔧 环境要求

- ✅ Docker Desktop 运行中
- ✅ 交叉编译工具在 `F:\新建文件夹`
  - qt-raspi.tar.xz
  - qt-host.tar.xz
  - my_piroot.tar
- ✅ 至少20GB可用磁盘空间

## 🐛 快速故障排查

### Docker未运行

```batch
# 启动Docker Desktop，等待图标变绿
```

### 找不到Docker镜像

```batch
cd docker\rk3588
docker build -t belt-control-rk3588:latest .
```

### 重新开始

```batch
# 删除所有构建文件
rmdir /s /q build_rk3588
rmdir /s /q output_rk3588
rmdir /s /q docker\rk3588\rk3588-libs

# 重新构建
docker\rk3588\build-rk3588.bat
```

## 📚 文档索引

| 文档 | 用途 |
|------|------|
| [RK3588快速开始.md](../../RK3588快速开始.md) | 30分钟入门 |
| [RK3588部署指南.md](../../RK3588部署指南.md) | 完整部署文档 |
| [DEPENDENCIES.md](DEPENDENCIES.md) | 多媒体库编译 |
| [README.md](README.md) | Docker环境说明 |
| [RK3588多媒体依赖库说明.md](../../RK3588多媒体依赖库说明.md) | 依赖库概述 |

## ⚡ 工作流程

### 典型开发流程

```batch
# 1. 首次设置（仅一次）
docker\rk3588\build-rk3588.bat          # 构建基础环境
docker\rk3588\build-dependencies.bat    # 编译多媒体库（可选）

# 2. 日常开发
# 在Windows上修改代码...

# 3. 测试部署
docker\rk3588\build-rk3588.bat          # 重新编译
docker\rk3588\deploy-to-rk3588.bat      # 部署到设备

# 4. 在RK3588上测试
ssh root@<RK3588_IP>
cd /opt/belt_control_system
./run.sh
```

## 💡 提示

- **首次构建**：约30-40分钟
- **增量构建**：约5分钟
- **网络需求**：首次需要下载Docker镜像（约1GB）
- **磁盘空间**：基础20GB + 依赖库10GB

## 🆘 紧急联系

遇到问题？

1. 检查本文档的故障排查章节
2. 查看详细文档（上方链接）
3. 检查Docker日志：`docker logs <container_id>`
4. 联系技术支持

---

🎉 祝您开发顺利！
