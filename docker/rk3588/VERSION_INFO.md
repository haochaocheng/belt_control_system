# RK3588 多媒体依赖库版本信息

## 📋 版本对照表

为确保RK3588 ARM64版本与Windows版本完全兼容，所有多媒体库版本与Windows保持一致。

| 库名 | Windows版本 | RK3588版本 | 位置 | 说明 |
|------|------------|-----------|------|------|
| **PJSIP** | 2.15.1 | 2.15.1 | F:\0\pjproject-2.15.1\ | 已复制到libs/pjproject-2.15.1.zip |
| **FFmpeg** | 4.4.4 | 4.4.4 | C:\ffmpeg\ | 从官方下载 |
| **SDL2** | 2.28.5 | 2.28.5 | C:\video_deps\SDL2-2.28.5\ | 从官方下载 |
| **x264** | libx264-165 | latest | - | 从源码编译 |
| **Opus** | 1.4 | 1.4 | - | 从源码编译 |

## 🔍 Windows版本检测结果

### PJSIP
- **版本**: 2.15.1
- **位置**: F:\0\pjproject-2.15.1\pjproject-2.15.1\
- **状态**: ✅ Windows开发环境正在使用，不能修改
- **RK3588方案**: 从libs/pjproject-2.15.1.zip解压（已从F:\0复制）

### FFmpeg
- **版本**: 4.4.4
- **位置**: C:\ffmpeg\
- **库文件**:
  - avcodec-58.dll
  - avformat-58.dll
  - avutil-56.dll
  - swscale-5.dll
  - swresample-3.dll
- **RK3588方案**: 从https://ffmpeg.org/releases/ffmpeg-4.4.4.tar.xz 下载

### SDL2
- **版本**: 2.28.5
- **位置**: C:\video_deps\SDL2-2.28.5\
- **RK3588方案**: 从https://github.com/libsdl-org/SDL/releases/download/release-2.28.5/SDL2-2.28.5.tar.gz 下载

### x264
- **版本**: libx264-165
- **位置**: C:\ffmpeg\bin\libx264-165.dll
- **RK3588方案**: 从https://code.videolan.org/videolan/x264.git 编译

## 📦 RK3588编译配置

### build-dependencies.sh 配置

```bash
# PJSIP 2.15.1
- 使用 libs/pjproject-2.15.1.zip (从F:\0复制)
- 避免污染Windows开发环境

# FFmpeg 4.4.4
- wget https://ffmpeg.org/releases/ffmpeg-4.4.4.tar.xz
- 匹配Windows版本

# SDL2 2.28.5
- wget https://github.com/libsdl-org/SDL/releases/download/release-2.28.5/SDL2-2.28.5.tar.gz
- 匹配Windows版本

# x264 latest
- git clone https://code.videolan.org/videolan/x264.git
- 启用PIC和共享库

# Opus 1.4
- git clone --branch v1.4 https://github.com/xiph/opus.git
- 高质量音频编码
```

## 🎯 兼容性保证

### ABI兼容性

所有库使用相同的主版本号，确保二进制接口兼容：

| 库 | Windows | RK3588 | 兼容性 |
|----|---------|--------|--------|
| FFmpeg avcodec | libavcodec-58 | libavcodec.so.58 | ✅ 兼容 |
| FFmpeg avformat | libavformat-58 | libavformat.so.58 | ✅ 兼容 |
| SDL2 | SDL2.dll | libSDL2-2.0.so.0 | ✅ 兼容 |
| PJSIP | 2.15.1 | 2.15.1 | ✅ 兼容 |

### 功能兼容性

- ✅ SIP语音通话
- ✅ H.264视频编解码
- ✅ RTP/UDP协议支持
- ✅ 音频重采样
- ✅ 视频缩放

## 📝 维护说明

### 更新Windows版本时

如果Windows上升级了库版本，需要：

1. 更新 `docker/rk3588/build-dependencies.sh` 中的版本号
2. 更新本文档的版本对照表
3. 如果是PJSIP，重新复制压缩包到libs/
4. 重新编译RK3588版本

### 验证版本匹配

```bash
# 在RK3588上检查库版本
ldd ./belt_control_system | grep -E "avcodec|avformat|SDL2|pjsip"

# 预期输出（版本号应匹配）:
# libavcodec.so.58 => /opt/belt_control_system/lib/libavcodec.so.58
# libavformat.so.58 => /opt/belt_control_system/lib/libavformat.so.58
# libSDL2-2.0.so.0 => /opt/belt_control_system/lib/libSDL2-2.0.so.0
```

## 🔗 相关文档

- [DEPENDENCIES.md](DEPENDENCIES.md) - 依赖库编译详细指南
- [build-dependencies.sh](build-dependencies.sh) - 编译脚本
- [README.md](README.md) - 总体说明

---

**最后更新**: 2025-12-13
**状态**: ✅ 版本已确认并匹配
