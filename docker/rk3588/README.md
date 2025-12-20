# RK3588 交叉编译环境

本目录包含将皮带控制系统交叉编译到RK3588 ARM64平台所需的所有文件。

## 📁 文件说明

```
docker/rk3588/
├── Dockerfile                   # Docker镜像定义
├── entrypoint.sh               # Docker入口脚本
├── toolchain-rk3588.cmake      # CMake工具链配置
├── build-rk3588.bat           # 一键构建脚本（Windows）
├── build-dependencies.sh       # 依赖库编译脚本（Shell）
├── build-dependencies.bat      # 依赖库编译脚本（Windows）
├── deploy-to-rk3588.bat       # 部署脚本（Windows）
├── DEPENDENCIES.md             # 依赖库编译指南
└── README.md                  # 本文件
```

## 🚀 快速开始

### 1. 准备工作

确保 `F:\新建文件夹` 包含：
- `qt-raspi.tar.xz` - Qt for ARM64
- `qt-host.tar.xz` - Qt Host Tools
- `my_piroot.tar` - RK3588 Sysroot

### 2. 构建

```batch
build-rk3588.bat
```

首次运行会：
- 解压所有工具（约10GB）
- 构建Docker镜像
- 交叉编译项目

后续运行只需重新编译（约5分钟）。

### 3. 部署

```batch
deploy-to-rk3588.bat
```

输入RK3588的IP和SSH用户名即可。

## 📦 输出文件

编译完成后，输出在 `../../output_rk3588/`：

```
output_rk3588/
├── belt_control_system       # ARM64可执行文件
├── config.ini               # 配置
├── run.sh                   # 启动脚本
├── lib/                     # 依赖库
│   ├── libsherpa-onnx-*.so
│   └── libonnxruntime.so
└── tts_models/              # TTS模型
```

## 🔧 高级用法

### 自定义工具路径

编辑 `build-rk3588.bat` 中的路径：

```batch
set "CROSS_TOOLS_DIR=F:\新建文件夹"
```

### 手动构建Docker镜像

```cmd
cd docker/rk3588
docker build -t belt-control-rk3588:latest .
```

### 进入Docker环境调试

```cmd
docker run -it --rm ^
    -v %CD%\..\..\:/workspace/belt_control_system ^
    -v %CD%\qt-host:/opt/qt-host:ro ^
    -v %CD%\qt-raspi:/opt/qt-raspi:ro ^
    -v %CD%\sysroot:/opt/sysroot:ro ^
    belt-control-rk3588:latest bash
```

### 手动编译

在Docker容器内：

```bash
cd /workspace/belt_control_system
mkdir build_rk3588 && cd build_rk3588

cmake \
    -DCMAKE_TOOLCHAIN_FILE=../docker/rk3588/toolchain-rk3588.cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DENABLE_SHERPA_ONNX=ON \
    ..

make -j4
```

## 🐛 故障排查

### 问题：Docker构建失败

```cmd
# 检查Docker状态
docker ps

# 查看Docker日志
docker logs <container_id>

# 重新拉取基础镜像
docker pull ubuntu:22.04
```

### 问题：找不到Qt

检查解压是否成功：

```cmd
dir docker\rk3588\qt-raspi
dir docker\rk3588\qt-host
```

应该看到完整的Qt目录结构。

### 问题：编译错误

查看完整的编译日志：

```cmd
type build_rk3588\CMakeFiles\CMakeOutput.log
type build_rk3588\CMakeFiles\CMakeError.log
```

## 🔧 编译多媒体依赖库（可选）

如果需要SIP电话和视频通话功能，需要额外编译PJSIP、FFmpeg等库：

```batch
build-dependencies.bat
```

详细说明请参考 [DEPENDENCIES.md](DEPENDENCIES.md)

## 📚 相关文档

- [RK3588部署指南.md](../../RK3588部署指南.md) - 详细部署说明
- [RK3588快速开始.md](../../RK3588快速开始.md) - 30分钟快速指南
- [DEPENDENCIES.md](DEPENDENCIES.md) - 依赖库编译指南
- [TTS性能优化完成.md](../../TTS性能优化完成.md) - TTS缓存优化
- [网络配置说明.md](../../网络配置说明.md) - Modbus网络配置

## 🔄 更新流程

### 代码更新后重新编译

```batch
build-rk3588.bat
deploy-to-rk3588.bat
```

### 清理重建

```cmd
# 删除构建目录
rmdir /s /q build_rk3588
rmdir /s /q output_rk3588

# 删除解压的工具（如果需要重新解压）
rmdir /s /q docker\rk3588\qt-raspi
rmdir /s /q docker\rk3588\qt-host
rmdir /s /q docker\rk3588\sysroot

# 重新构建
build-rk3588.bat
```

## 🎯 技术细节

### 工具链

- **编译器**: GCC 11 aarch64-linux-gnu
- **目标架构**: ARM64 (aarch64)
- **指令集**: ARMv8-A
- **Qt版本**: 6.x (从qt-raspi.tar.xz)

### 构建系统

- **CMake**: 3.16+
- **Ninja**: 构建工具
- **Toolchain**: toolchain-rk3588.cmake

### 依赖库

**核心依赖**:
- **Qt6**: Widgets, Multimedia, Network, SerialBus
- **Sherpa-ONNX**: ARM64版本（v1.12.9）
- **系统库**: 从sysroot获取

**可选依赖**（用于SIP电话和视频功能）:
- **PJSIP**: SIP协议栈
- **FFmpeg**: 视频编解码
- **SDL2**: 媒体渲染
- **x264**: H.264编码
- **Opus**: 音频编码

编译可选依赖请参考 [DEPENDENCIES.md](DEPENDENCIES.md)

## 💡 最佳实践

1. **首次构建**: 预留30分钟和20GB磁盘空间
2. **网络**: 确保网络畅通（Docker需要下载镜像）
3. **备份**: 定期备份output_rk3588目录
4. **测试**: 在RK3588上充分测试后再部署生产
5. **版本管理**: 使用Git管理代码和配置

## 📞 支持

遇到问题？

1. 查看 [RK3588部署指南.md](../../RK3588部署指南.md) 的故障排查章节
2. 检查Docker日志和编译日志
3. 确认所有前置条件满足
4. 联系技术支持

---

🎉 祝您部署顺利！
