# Qt Multimedia 插件缺失问题分析

**日期**: 2026-01-09 15:10
**问题**: 视频帧到达 RemoteVideoManager 但屏幕不显示（仅 Linux 设备）
**状态**: 🔴 **根因已确认 - Qt Multimedia 后端未安装**

---

## 🔍 问题现象

### Windows 平台 vs Linux 设备

| 平台 | Qt Multimedia 后端 | 视频显示 | VideoSinkItem 日志 |
|------|-------------------|---------|-------------------|
| **Windows 开发机** | ✅ 完整后端（DirectShow/WMF） | ✅ 正常显示 | ✅ 正常输出 |
| **Linux 设备 (ARM64)** | ❌ 缺少 FFmpeg 插件 | ❌ 黑屏 | ❌ 完全无日志 |

### 启动日志中的关键警告

**文件**: docs/log/startup_debug_latest.log

**Line 60-62**:
```
[WARNING] could not load multimedia backend "ffmpeg"
[CRITICAL] QtMultimedia is not currently supported on this platform or compiler.
[WARNING] Failed to initialize QMediaPlayer "Not available"
```

**Line 115-121**:
```
[WARNING] Failed to create QVideoSink "Not available"
[DEBUG] ✅ QVideoSink created
[WARNING] Failed to initialize QMediaCaptureSession "Not available"
[DEBUG] ✅ QMediaCaptureSession created and connected to video sink
[WARNING] Failed to create QVideoSink "Not available"
[DEBUG] ✅ LocalVideoManager created (PJSIP preview mode)
```

**Line 181-183** (QML 连接成功):
```
[DEBUG] ✅ Remote VideoSinkItem created
[DEBUG] ✅ Connected to video sink, waiting for frames...
[DEBUG] ✅ Remote VideoSinkItem connected to video sink
```

---

## 🎯 根本原因分析

### QML 绑定代码正确

**文件**: src/qml/components/sip_phone/pages/SipDialPage.qml (Line 309-322)

```qml
VideoSinkItem {
    id: remoteVideoSink
    anchors.fill: parent
    anchors.margins: 2

    Component.onCompleted: {
        console.log("✅ Remote VideoSinkItem created")
        // 安全地连接到 remote video manager 的 video sink
        if (SipPhoneManager && SipPhoneManager.remoteVideoManager) {
            sink = SipPhoneManager.remoteVideoManager.videoSink
            console.log("✅ Remote VideoSinkItem connected to video sink")
        } else {
            console.log("❌ RemoteVideoManager not available")
        }
    }
}
```

✅ **QML 绑定完全正确**，启动日志确认连接成功。

### 数据管道断链位置

```
RemoteVideoManager::displayFrame()          ✅ 正常（76 帧）
  ↓ 调用
m_videoSink->setVideoFrame(frame)          ✅ 调用成功
  ↓ 应该触发信号
QVideoSink (无后端支持)                     ❌ **空壳对象，没有后端实现**
  ↓
QVideoSink::videoFrameChanged              ❌ **信号永远不会触发**
  ↓
VideoSinkItem::onVideoFrameChanged()       ❌ 永远不会被调用
  ↓
VideoSinkItem::updatePaintNode()           ❌ 永远不会渲染
```

### 为什么 Windows 正常？

**Windows Qt Multimedia 后端**:
- DirectShow (传统)
- Windows Media Foundation (现代)
- 这些后端随 Qt 安装自动部署

**Linux Qt Multimedia 后端**:
- FFmpeg 插件
- GStreamer 插件
- **需要额外安装包**（当前未安装）

### 问题根因

**Docker 容器中缺少 Qt6 Multimedia 插件包**，导致：

1. `QVideoSink` 可以创建（C++ 对象），但没有实际后端支持
2. `setVideoFrame()` 调用成功，但内部无任何操作
3. `videoFrameChanged` 信号永远不会触发
4. VideoSinkItem 永远收不到帧数据

---

## 📦 Dockerfile 分析

### Dockerfile.ubuntu24-base (基础镜像)

**文件**: Dockerfile.ubuntu24-base

**安装的包** (Line 16-104):
```dockerfile
RUN apt-get update && apt-get install -y \
    # Audio and multimedia
    libasound2t64 \
    libopus0 \
    libsdl2-2.0-0 \
    \
    # Video/Audio codecs
    libvpx9 \
    libx264-164 \
    libx265-199 \
    # ... (其他系统库)
```

❌ **缺少的关键包**:
- `libqt6multimedia6` - Qt Multimedia 核心库
- `libqt6multimedia6-plugins` - Qt Multimedia 插件（FFmpeg 后端）
- `qml6-module-qtmultimedia` - Qt Multimedia QML 模块
- `ffmpeg` - FFmpeg 命令行工具（可选，但推荐）

### Dockerfile.ubuntu24-apt (应用层镜像)

**文件**: Dockerfile.ubuntu24-apt

**操作** (Line 7-92):
```dockerfile
FROM --platform=linux/arm64 belt-control-base:ubuntu24

# Copy application files
COPY belt_control_system /app/belt_control_system
COPY sherpa_tts_service /app/sherpa_tts_service
COPY lib /app/lib
COPY plugins /app/plugins
COPY qml /app/qml
# ...
```

✅ 应用层只复制文件，不安装系统包（符合分层设计）
❌ 基础镜像未安装 Qt Multimedia 插件

---

## 🛠️ 解决方案

### 方案 A：修改基础镜像（推荐 ⭐⭐⭐⭐⭐）

**优点**:
- 一次修改，所有应用受益
- 符合 Docker 分层设计
- 基础镜像缓存，不影响应用层重建速度

**缺点**:
- 需要重新构建基础镜像（一次性操作）
- 镜像体积增加约 50-100 MB

**实施步骤**:

1. **修改 Dockerfile.ubuntu24-base**，在 Line 16 的 `apt-get install` 中添加：

```dockerfile
RUN apt-get update && apt-get install -y \
    # ... (现有包) ...
    \
    # ✅ 2026-01-09 15:10 [修复 96] Qt6 Multimedia 支持（解决 Linux 视频显示问题）
    # 问题：QVideoSink 无后端支持，videoFrameChanged 信号不触发
    # 根因：容器缺少 Qt Multimedia FFmpeg 插件
    # 效果：VideoSinkItem 可以正常接收和渲染视频帧
    libqt6multimedia6 \
    libqt6multimedia6-plugins \
    qml6-module-qtmultimedia \
    ffmpeg \
    \
    # ... (GDB 等其他工具) ...
```

2. **重新构建基础镜像**:

```powershell
# 删除旧基础镜像
docker rmi belt-control-base:ubuntu24

# 运行构建脚本（会自动重建基础镜像）
.\build-ubuntu24-apt.ps1 188
```

3. **验证插件加载**:

```powershell
# 检查启动日志，应该看到：
# ✅ QVideoSink created (no warnings)
# ✅ Multimedia backend loaded
```

### 方案 B：仅安装 FFmpeg 插件（不推荐）

在应用层 Dockerfile 中安装，但违反分层设计原则。

---

## 📊 预期效果

### 修复后的启动日志

**期望**:
```
[DEBUG] ✅ QVideoSink created
[DEBUG] ✅ Qt Multimedia FFmpeg backend loaded
[DEBUG] ✅ RemoteVideoManager created (Event-driven Push mode + Async v6)
```

**不再出现**:
```
[WARNING] could not load multimedia backend "ffmpeg"  ← 将消失
[CRITICAL] QtMultimedia is not currently supported...  ← 将消失
```

### 修复后的运行日志

**期望**:
```
📹 [DISPLAY FRAME] Presenting to QVideoSink: frame 1
📹 [VIDEO SINK ITEM] Received frame 1 size: 640 x 360  ← 将出现！
📹 [PAINT NODE] Rendering frame 1 image: 640 x 360     ← 将出现！
```

### 最终效果

| 项目 | 修复前 | 修复后 |
|------|--------|--------|
| **启动警告** | ❌ Qt Multimedia 不支持 | ✅ 无警告 |
| **QVideoSink 后端** | ❌ 空壳对象 | ✅ FFmpeg 后端 |
| **videoFrameChanged 信号** | ❌ 永不触发 | ✅ 每帧触发 |
| **VideoSinkItem 日志** | ❌ 完全无日志 | ✅ 正常输出 |
| **视频显示** | ❌ 黑屏 | ✅ 正常显示 |

---

## 🎉 关键发现总结

### ✅ 已确认正常

1. ✅ RemoteVideoManager 正常工作（76 帧成功传递）
2. ✅ QML VideoSinkItem 正确绑定到 RemoteVideoManager.videoSink
3. ✅ Fix 95 解码错误已完全解决（无 PJ_ENOTFOUND）
4. ✅ 硬件解码正常（DRM_PRIME → NV12）
5. ✅ C++ → QML 数据传递正常

### ❌ 发现的问题

1. ❌ **Docker 容器缺少 Qt6 Multimedia 插件包**
2. ❌ QVideoSink 是空壳对象，无后端支持
3. ❌ videoFrameChanged 信号永远不触发
4. ❌ VideoSinkItem 永远收不到帧数据

### 🎯 根本原因

**平台差异导致的依赖缺失**:
- Windows: Qt 安装自带 DirectShow/WMF 后端 ✅
- Linux: 需要额外安装 FFmpeg 插件包 ❌（当前未安装）

---

**创建时间**: 2026-01-09 15:10
**分析文件**: startup_debug_latest.log, voip.md, SipDialPage.qml
**下一步**: 修改 Dockerfile.ubuntu24-base 添加 Qt Multimedia 插件包
**优先级**: 🔥 最高 - 最后一公里，平台依赖问题
