# RK3588 交叉编译 GLIBC 兼容性问题修复

## 问题描述
在使用 `build-ubuntu24-apt.ps1` 进行交叉编译时，链接阶段失败，出现大量 GLIBC 版本不匹配错误：
- `/opt/rk3588-libs` 中的库需要 GLIBC 2.33-2.38
- Docker 容器基于 Ubuntu 24.04（GLIBC 2.39）
- 导致链接时出现数百个未定义符号引用

## 根本原因
1. 预编译的 rk3588-libs 来自目标设备，与编译环境的 GLIBC 版本不兼容
2. 缺失大量系统库（libX11, libXext, liblzma 等）
3. 传递性依赖无法正确解析

## 解决方案

### 1. 新建修复版 Docker 镜像 (`Dockerfile.fixed`)
- 基于 Ubuntu 24.04（保持 GLIBC 2.39）
- 启用 ARM64 架构支持：`dpkg --add-architecture arm64`
- 直接在容器中安装所有必需的 ARM64 库
- 这确保所有库使用相同的 GLIBC 版本

### 2. 新建修复版工具链配置 (`toolchain-fixed.cmake`)
- 优先使用容器内的 ARM64 库：`/usr/lib/aarch64-linux-gnu`
- 不再依赖预编译的 `/opt/rk3588-libs`
- 添加 `--allow-shlib-undefined` 标志允许某些符号在运行时解析

### 3. 新建编译脚本 (`build-rk3588-fixed.ps1`)
- 使用新的 Docker 镜像和工具链配置
- 不再挂载 rk3588-libs 目录
- 提供详细的编译输出（VERBOSE=1）

### 4. 修改主脚本 (`build-ubuntu24-apt.ps1`)
- 第 172 行：调用 `build-rk3588-fixed.ps1` 而非 `build-rk3588.ps1`

## 使用方法

### 首次编译（构建 Docker 镜像）
```powershell
.\build-rk3588-fixed.ps1
# 或通过主脚本
.\build-ubuntu24-apt.ps1 151
```

### 重新构建 Docker 镜像（如需添加新库）
```powershell
.\build-rk3588-fixed.ps1 -RebuildImage
```

### 清理构建并重新编译
```powershell
.\build-rk3588-fixed.ps1 -CleanBuild
```

## 文件清单

| 文件 | 说明 |
|------|------|
| `docker/rk3588/Dockerfile.fixed` | 修复版 Docker 镜像定义，包含所有 ARM64 库 |
| `docker/rk3588/toolchain-fixed.cmake` | 修复版工具链配置，使用容器内库 |
| `build-rk3588-fixed.ps1` | 修复版编译脚本 |
| `build-ubuntu24-apt.ps1` | 主脚本（已修改使用修复版） |

## 技术细节

### Docker 镜像改进
- 安装了约 60 个 ARM64 库包
- 包括 X11、XCB、Wayland、音频、压缩等所有依赖
- 所有库版本与编译环境一致（GLIBC 2.39）

### 工具链配置改进
- 设置 `CONTAINER_ARM64_LIBS=/usr/lib/aarch64-linux-gnu`
- 链接器标志优先搜索容器内库
- PKG_CONFIG 配置指向容器内的 `.pc` 文件

## 验证方法

### 检查库是否正确安装
```powershell
docker run --rm belt-control-fixed:latest /check-libs.sh
```

### 验证编译后的二进制链接
```powershell
docker run --rm -v "e:/2025/3_gongkongji/belt_control_system:/workspace" belt-control-fixed:latest ldd /workspace/build_rk3588/bin_arm64/belt_control_system
```

## 故障排除

如果仍有链接错误：
1. 检查错误信息中缺失的库
2. 在 `Dockerfile.fixed` 中添加对应的 ARM64 包
3. 重新构建镜像：`.\build-rk3588-fixed.ps1 -RebuildImage`

## 注意事项
- 首次构建镜像需要下载约 500MB 的包，建议启用代理
- 镜像构建后会缓存，后续编译速度很快
- 编译的二进制文件使用 Ubuntu 24.04 的库版本，确保部署环境兼容