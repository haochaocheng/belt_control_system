# Fix 96: Qt Multimedia 插件依赖问题解决方案

**日期**: 2026-01-09 15:25
**问题**: Qt Multimedia 插件存在但无法加载
**状态**: 🔴 **FFmpeg 和 GStreamer 插件都缺少依赖**

---

## 🔍 问题验证

### 插件存在性确认

**容器路径**: `/app/plugins/multimedia/`

```bash
$ docker exec belt-control-app ls -lh /app/plugins/multimedia
-rwxr-xr-x 1 root root 714K Oct 27  2024 libffmpegmediaplugin.so       ✅ 存在
-rwxr-xr-x 1 root root 607K Oct 27  2024 libgstreamermediaplugin.so    ✅ 存在
```

### FFmpeg 插件依赖检查

**问题**: **版本不匹配**

| 插件需要（FFmpeg 4.x） | 容器实际（FFmpeg 6.x） | 状态 |
|----------------------|----------------------|-----|
| libavcodec.so.58     | libavcodec.so.60     | ❌ 不匹配 |
| libavformat.so.58    | libavformat.so.60    | ❌ 不匹配 |
| libavutil.so.56      | libavutil.so.58      | ❌ 不匹配 |
| libswresample.so.3   | libswresample.so.4   | ❌ 不匹配 |
| libswscale.so.5      | libswscale.so.7      | ❌ 不匹配 |

**ldd 输出**:
```
libavformat.so.58 => not found
libavcodec.so.58 => not found
libswresample.so.3 => not found
libswscale.so.5 => not found
libavutil.so.56 => not found
```

**根因**: Qt Multimedia 插件编译时链接到 FFmpeg 4.x，但容器运行时使用 FFmpeg 6.x（nyanmisaka/ffmpeg-rockchip）

### GStreamer 插件依赖检查

**问题**: **完全缺失**

**ldd 输出**:
```
libgstphotography-1.0.so.0 => not found
libgstpbutils-1.0.so.0 => not found
libgstapp-1.0.so.0 => not found
libgstallocators-1.0.so.0 => not found
libgstgl-1.0.so.0 => not found
libgstvideo-1.0.so.0 => not found
libgstbase-1.0.so.0 => not found
libgstreamer-1.0.so.0 => not found
```

**根因**: 容器中未安装 GStreamer 库

---

## 🛠️ 解决方案

### ⭐ 方案 A：安装 GStreamer 库（推荐）

**优点**:
- ✅ 简单快速（apt-get install）
- ✅ 不会与现有 FFmpeg 6.x 冲突
- ✅ GStreamer 是 Qt Multimedia 的标准后端
- ✅ 兼容性好

**缺点**:
- ⚠️ 镜像体积增加约 30-50 MB

**实施步骤**:

#### 1. 修改 Dockerfile.ubuntu24-base

在 Line 16 的 `apt-get install` 中添加 GStreamer 包：

```dockerfile
RUN apt-get update && apt-get install -y \
    # ... (现有包) ...
    \
    # ✅ 2026-01-09 15:25 [修复 96] GStreamer 支持（Qt Multimedia 后端）
    # 问题：Qt Multimedia 插件存在但无法加载
    # 根因 1: FFmpeg 插件需要 FFmpeg 4.x，容器使用 FFmpeg 6.x（版本不匹配）
    # 根因 2: GStreamer 插件缺少 GStreamer 库
    # 策略：安装 GStreamer 1.0 库，使用 GStreamer 后端
    # 效果：VideoSinkItem 可以正常接收和渲染视频帧
    libgstreamer1.0-0 \
    libgstreamer-plugins-base1.0-0 \
    libgstreamer-plugins-good1.0-0 \
    libgstreamer-plugins-bad1.0-0 \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-libav \
    gstreamer1.0-tools \
    \
    # ... (GDB 等其他工具) ...
```

**包说明**:
- `libgstreamer1.0-0` - GStreamer 核心库
- `libgstreamer-plugins-base1.0-0` - 基础插件（必需）
- `libgstreamer-plugins-good1.0-0` - 良好质量插件
- `libgstreamer-plugins-bad1.0-0` - 实验性插件
- `gstreamer1.0-plugins-*` - 插件包
- `gstreamer1.0-libav` - FFmpeg 集成（重要！）
- `gstreamer1.0-tools` - 调试工具（可选）

#### 2. 重新构建基础镜像

```powershell
# 删除旧基础镜像
docker rmi belt-control-base:ubuntu24

# 运行构建脚本（会自动重建基础镜像）
.\build-ubuntu24-apt.ps1 188
```

#### 3. 验证 GStreamer 加载

**启动日志预期**:
```
[DEBUG] ✅ QVideoSink created
[DEBUG] ✅ Qt Multimedia GStreamer backend loaded  ← 应该出现
[DEBUG] ✅ RemoteVideoManager created
```

**不再出现**:
```
[WARNING] could not load multimedia backend "ffmpeg"   ← 将消失
[CRITICAL] QtMultimedia is not currently supported...  ← 将消失
```

#### 4. 测试视频显示

**运行日志预期**:
```
📹 [DISPLAY FRAME] Presenting to QVideoSink: frame 1
📹 [VIDEO SINK ITEM] Received frame 1 size: 640 x 360  ← 应该出现
📹 [PAINT NODE] Rendering frame 1 image: 640 x 360     ← 应该出现
```

---

### 方案 B：重新编译 Qt Multimedia 插件（不推荐）

**优点**:
- ✅ 使用 FFmpeg 6.x 后端（与 PJSIP 一致）
- ✅ 镜像体积不增加

**缺点**:
- ❌ 需要重新编译整个 Qt 6.5.3（耗时数小时）
- ❌ 配置复杂（需要 FFmpeg 6.x 开发包）
- ❌ 维护成本高

**不推荐原因**: 成本收益比不合理

---

### 方案 C：安装 FFmpeg 4.x 库（不推荐）

**优点**:
- ✅ 不需要修改 Qt 插件

**缺点**:
- ❌ 两个 FFmpeg 版本共存（4.x 和 6.x）
- ❌ 可能导致符号冲突
- ❌ 镜像体积显著增加（+100 MB）
- ❌ 维护复杂

**不推荐原因**: 版本冲突风险高

---

## 📊 方案对比

| 方案 | 难度 | 时间 | 镜像体积 | 稳定性 | 推荐度 |
|------|------|------|---------|--------|--------|
| **A. 安装 GStreamer** | ⭐ 简单 | 5 分钟 | +30 MB | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| B. 重新编译 Qt | ⭐⭐⭐⭐⭐ 困难 | 4-6 小时 | +0 MB | ⭐⭐⭐⭐ | ⭐ |
| C. 双 FFmpeg 版本 | ⭐⭐ 中等 | 10 分钟 | +100 MB | ⭐⭐ | ⭐⭐ |

**推荐**: 方案 A

---

## 🎯 预期效果（方案 A）

### 启动日志对比

#### 修复前
```
[WARNING] could not load multimedia backend "ffmpeg"
[CRITICAL] QtMultimedia is not currently supported on this platform or compiler.
[WARNING] Failed to initialize QMediaPlayer "Not available"
[WARNING] Failed to create QVideoSink "Not available"
```

#### 修复后
```
[DEBUG] ✅ QVideoSink created
[DEBUG] ✅ Qt Multimedia GStreamer backend loaded
[DEBUG] ✅ GStreamer version: 1.24.x
```

### 运行日志对比

#### 修复前
```
📹 [DISPLAY FRAME] Presenting to QVideoSink: frame 1
(无 VideoSinkItem 日志)
(无 PAINT NODE 日志)
```

#### 修复后
```
📹 [DISPLAY FRAME] Presenting to QVideoSink: frame 1 size: 640 x 360
📹 [VIDEO SINK ITEM] Received frame 1 size: 640 x 360 valid: true
📹 [PAINT NODE] Rendering frame 1 image: 640x360 item size: 800x600
📹 [PAINT NODE] Created texture from image: QSize(640, 360)
```

### 最终效果

| 项目 | 修复前 | 修复后 |
|------|--------|--------|
| **Multimedia 后端** | ❌ 无后端 | ✅ GStreamer 1.24 |
| **插件依赖** | ❌ FFmpeg 4.x 缺失 | ✅ GStreamer 库完整 |
| **QVideoSink 功能** | ❌ 空壳对象 | ✅ 完整功能 |
| **videoFrameChanged 信号** | ❌ 永不触发 | ✅ 每帧触发 |
| **VideoSinkItem 日志** | ❌ 完全无日志 | ✅ 正常输出 |
| **视频显示** | ❌ 黑屏 | ✅ 正常显示 |

---

## 🔧 调试命令（方案 A）

### 验证 GStreamer 安装

```bash
# 检查 GStreamer 版本
docker exec belt-control-app gst-inspect-1.0 --version

# 检查插件依赖
docker exec belt-control-app ldd /app/plugins/multimedia/libgstreamermediaplugin.so | grep gst

# 测试 GStreamer 管道
docker exec belt-control-app gst-launch-1.0 videotestsrc ! autovideosink
```

### 验证插件加载

```bash
# 查看 Qt 插件路径
docker exec belt-control-app printenv QT_PLUGIN_PATH

# 检查插件可执行权限
docker exec belt-control-app ls -l /app/plugins/multimedia/
```

---

## 📝 修改清单（方案 A）

### 需要修改的文件

1. **Dockerfile.ubuntu24-base**
   - Line ~16: 添加 GStreamer 包

### 需要执行的命令

```powershell
# 1. 删除旧基础镜像
docker rmi belt-control-base:ubuntu24

# 2. 重新构建（自动重建基础镜像）
.\build-ubuntu24-apt.ps1 188

# 3. 验证视频显示
# （在设备上运行应用，拨打视频电话）
```

---

## 🎉 关键发现总结

### ✅ 已确认正常

1. ✅ Qt Multimedia 插件已编译并部署到容器
2. ✅ 插件文件存在：libffmpegmediaplugin.so, libgstreamermediaplugin.so
3. ✅ QML VideoSinkItem 正确绑定
4. ✅ 插件路径配置正确（QT_PLUGIN_PATH=/app/plugins）

### ❌ 发现的问题

1. ❌ **FFmpeg 插件**: 需要 FFmpeg 4.x，容器使用 FFmpeg 6.x（版本不匹配）
2. ❌ **GStreamer 插件**: 缺少 GStreamer 1.0 库（完全未安装）
3. ❌ 插件无法加载导致 QVideoSink 无后端支持

### 🎯 根本原因

**Qt 插件编译时链接的库版本与运行时容器环境不匹配**:
- Qt 编译环境: FFmpeg 4.x
- 容器运行环境: FFmpeg 6.x
- GStreamer: 完全缺失

---

**创建时间**: 2026-01-09 15:25
**推荐方案**: 方案 A - 安装 GStreamer 库
**下一步**: 修改 Dockerfile.ubuntu24-base 添加 GStreamer 包
**优先级**: 🔥 最高 - 最后一公里，依赖版本问题
