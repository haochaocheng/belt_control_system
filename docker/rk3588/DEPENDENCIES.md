# RK3588 依赖库编译指南

## 📋 概述

本指南说明如何为RK3588 ARM64平台交叉编译多媒体依赖库，包括PJSIP、FFmpeg、SDL2等。

## 🎯 支持的库

| 库名 | 版本 | 用途 | 编译时间 |
|------|------|------|---------|
| **OpenSSL** | 3.3.2 | 加密库 (匹配Windows版本) | ~5分钟 |
| **Opus** | v1.4 | 高质量音频编码 | ~3分钟 |
| **x264** | latest | H.264视频编码 | ~5分钟 |
| **FFmpeg** | 4.4.4 | 视频处理和转码 (匹配Windows版本) | ~10分钟 |
| **SDL2** | 2.28.5 | 媒体渲染库 | ~3分钟 |
| **PJSIP** | 2.15.1 | SIP协议栈 (匹配Windows版本) | ~8分钟 |

## 🚀 快速开始

### 前置条件

1. ✅ 已运行 `build-rk3588.bat` 构建基础Docker镜像
2. ✅ Docker Desktop 正在运行
3. ✅ 至少10GB可用磁盘空间

### 编译所有库（推荐）

```batch
docker\rk3588\build-dependencies.bat
```

按提示选择 `1` 编译所有库，约30分钟完成。

### 编译单个库

```batch
REM 仅编译PJSIP
docker\rk3588\build-dependencies.bat 6

REM 仅编译FFmpeg
docker\rk3588\build-dependencies.bat 4
```

## 📦 输出文件

编译完成后，库文件位于 `docker/rk3588/rk3588-libs/`：

```
docker/rk3588/rk3588-libs/
├── lib/                    # 动态库
│   ├── libopus.so.0
│   ├── libx264.so.164
│   ├── libavcodec.so.60
│   ├── libavformat.so.60
│   ├── libavutil.so.58
│   ├── libSDL2-2.0.so.0
│   ├── libpjsip.so
│   ├── libpjsua.so
│   └── ...
├── include/                # 头文件
│   ├── opus/
│   ├── x264.h
│   ├── libavcodec/
│   ├── SDL2/
│   ├── pjsip/
│   └── ...
└── lib/pkgconfig/         # pkg-config文件
    ├── opus.pc
    ├── x264.pc
    ├── libavcodec.pc
    └── ...
```

## 🔧 高级用法

### 手动进入Docker环境

如需调试编译过程：

```cmd
docker run -it --rm ^
    -v %CD%\..\..\:/workspace/belt_control_system ^
    -v %CD%\qt-host:/opt/qt-host:ro ^
    -v %CD%\qt-raspi:/opt/qt-raspi:ro ^
    -v %CD%\sysroot:/opt/sysroot:ro ^
    -v %CD%\rk3588-libs:/opt/rk3588-libs ^
    belt-control-rk3588:latest bash
```

在容器内：

```bash
# 编译所有库
/workspace/belt_control_system/docker/rk3588/build-dependencies.sh

# 编译单个库
/workspace/belt_control_system/docker/rk3588/build-dependencies.sh pjsip
```

### 清理重建

删除已编译的库：

```cmd
rmdir /s /q docker\rk3588\rk3588-libs
```

然后重新运行 `build-dependencies.bat`。

### 修改编译选项

编辑 `build-dependencies.sh` 中的构建函数，例如：

```bash
# 修改FFmpeg配置
build_ffmpeg() {
    ./configure \
        --prefix=${PREFIX} \
        --enable-cross-compile \
        --arch=aarch64 \
        # ... 添加或修改选项
}
```

## 🔍 各库说明

### 0. OpenSSL

**用途**: 加密库，提供SSL/TLS支持，PJSIP等库依赖

**版本**: 3.3.2 (匹配Windows版本)

**配置**:
- 启用共享库
- 禁用弱加密算法
- 禁用SSL 3.0
- ARM64优化

**依赖**: 无

**注意**: OpenSSL最先编译，因为PJSIP、FFmpeg等库可能依赖它

### 1. Opus

**用途**: 高质量、低延迟的音频编码，用于SIP语音通话

**配置**:
- 共享库和静态库
- 默认配置，适合实时通信

**依赖**: 无

### 2. x264

**用途**: H.264视频编码，用于视频通话

**配置**:
- 共享库和静态库
- 启用PIC（位置无关代码）
- 针对ARM优化

**依赖**: 无

### 3. FFmpeg

**用途**: 视频处理、编解码、格式转换

**版本**: 4.4.4 (匹配Windows版本)

**配置**:
- 启用x264编码器
- 启用H.264解码器
- 支持RTP/UDP协议
- 禁用文档和示例程序（减小体积）

**依赖**: x264（必须先编译）

### 4. SDL2

**用途**: 跨平台媒体库，用于视频渲染和音频播放

**配置**:
- 仅共享库
- 使用CMake构建
- 启用EGL支持（RK3588 GPU）

**依赖**: 系统OpenGL ES库

### 5. PJSIP

**用途**: 完整的SIP协议栈，支持语音和视频通话

**版本**: 2.15.1 (匹配Windows版本，使用libs/pjproject-2.15.1.zip)

**配置**:
- 禁用OSS音频（嵌入式系统）
- 共享库
- 禁用视频和声音设备（使用自定义实现）
- 启用PIC

**依赖**: Opus（可选，提高音质）

**注意**: 使用本地压缩包解压，避免污染Windows开发环境中的F:\0\pjproject-2.15.1目录

## 🐛 故障排查

### 问题1: Docker镜像不存在

**症状**:
```
❌ 错误: 找不到Docker镜像 belt-control-rk3588:latest
```

**解决**: 先运行 `build-rk3588.bat` 构建基础镜像

### 问题2: 编译失败 - 找不到工具链

**症状**:
```
configure: error: cannot find aarch64-linux-gnu-gcc
```

**解决**: 检查Docker镜像是否正确构建，重新构建镜像：
```cmd
cd docker\rk3588
docker build -t belt-control-rk3588:latest .
```

### 问题3: 编译失败 - 找不到依赖

**症状**:
```
ERROR: x264 not found
```

**解决**: 按顺序编译库：
1. Opus
2. x264
3. FFmpeg (依赖x264)
4. SDL2
5. PJSIP

或者直接编译所有库（自动处理依赖顺序）。

### 问题4: 权限错误

**症状**:
```
Permission denied: /opt/rk3588-libs
```

**解决**: 删除并重建输出目录：
```cmd
rmdir /s /q docker\rk3588\rk3588-libs
mkdir docker\rk3588\rk3588-libs
```

### 问题5: 磁盘空间不足

**症状**:
```
No space left on device
```

**解决**:
1. 清理Docker缓存：`docker system prune -a`
2. 删除临时构建文件（容器内 /tmp/build_deps）
3. 释放至少10GB磁盘空间

## 📊 编译时间参考

在典型的开发机器上（8核CPU，16GB RAM）：

| 操作 | 时间 |
|------|------|
| 编译Opus | 3分钟 |
| 编译x264 | 5分钟 |
| 编译FFmpeg | 10分钟 |
| 编译SDL2 | 3分钟 |
| 编译PJSIP | 8分钟 |
| **总计** | **约30分钟** |

## 🔄 集成到主程序

### 自动集成

编译依赖库后，运行 `build-rk3588.bat` 会自动：
1. 检测 `rk3588-libs/` 目录
2. 在CMake中添加库路径
3. 链接必要的库

### 手动配置

如需手动配置，编辑 `CMakeLists.txt`：

```cmake
# 添加RK3588依赖库路径
if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64")
    set(RK3588_LIBS_DIR "${CMAKE_SOURCE_DIR}/docker/rk3588/rk3588-libs")

    if(EXISTS ${RK3588_LIBS_DIR})
        include_directories(${RK3588_LIBS_DIR}/include)
        link_directories(${RK3588_LIBS_DIR}/lib)

        # 链接PJSIP
        target_link_libraries(your_target
            pjsua pjsip pjmedia pjnath pjlib-util pj
        )

        # 链接FFmpeg
        target_link_libraries(your_target
            avcodec avformat avutil swscale
        )

        # 链接SDL2
        target_link_libraries(your_target SDL2)

        # 链接Opus
        target_link_libraries(your_target opus)
    endif()
endif()
```

## 📝 部署到RK3588

### 复制库文件

`build-rk3588.bat` 会自动复制库文件到 `output_rk3588/lib/`。

手动复制：

```batch
xcopy /E /I docker\rk3588\rk3588-libs\lib\*.so* output_rk3588\lib\
```

### 在RK3588上设置

SSH登录RK3588后：

```bash
# 设置库路径
export LD_LIBRARY_PATH=/opt/belt_control_system/lib:$LD_LIBRARY_PATH

# 验证库文件
ldd /opt/belt_control_system/belt_control_system

# 运行程序
./belt_control_system
```

## 💡 最佳实践

1. **首次编译**: 预留40分钟和10GB磁盘空间
2. **按需编译**: 如果不需要视频功能，可以跳过FFmpeg和SDL2
3. **版本管理**: 编译完成后，可以打包 `rk3588-libs/` 作为预编译包
4. **缓存机制**: Docker会缓存已下载的源代码，第二次编译更快
5. **并行编译**: 脚本自动使用 `nproc` 确定CPU核心数

## 🔗 相关文档

- [RK3588部署指南](../../RK3588部署指南.md) - 完整部署流程
- [RK3588快速开始](../../RK3588快速开始.md) - 30分钟快速指南
- [README](README.md) - Docker环境说明

## 📞 技术支持

遇到问题？

1. 查看本文档的故障排查章节
2. 检查Docker日志：`docker logs <container_id>`
3. 查看编译日志：容器内 `/tmp/build_deps/*/config.log`
4. 联系技术支持

---

🎉 祝您编译顺利！
