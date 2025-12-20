# SIP 视频通话功能实施计划

## 项目目标

为皮带控制系统添加完整的 SIP 视频通话功能，支持：
- Windows x64 平台（主要开发平台）
- AArch64 Linux 平台（嵌入式工控机平台）

## 技术栈

### 核心组件
1. **PJSIP** - SIP 协议栈，提供音视频通话能力
2. **FFmpeg** - 视频编解码（H.264/H.265）
3. **SDL2** - 视频渲染和显示
4. **Qt/QML** - UI 框架

### 编解码器
- **视频**: H.264 (首选), VP8/VP9 (备选)
- **音频**: Opus, G.711

---

## 实施阶段

## 阶段 1：调研和规划 ✅ [当前阶段]

### 1.1 分析现有代码

**已发现**:
- ✅ 项目中有 `pjmedia_vid_dev_stub.c` - 说明当前 PJSIP 未启用视频
- ✅ Risip SDK 中有视频相关注释
- ❌ 当前 PJSIP 编译时禁用了视频支持

**需要检查**:
- [ ] PJSIP 版本和编译配置
- [ ] Risip SDK 的视频 API 支持程度
- [ ] 参考 pjsip-apps/vidgui 示例代码

### 1.2 确定依赖版本

**FFmpeg** (推荐):
- 版本: 5.1.x 或 6.0.x (稳定版)
- 组件: libavcodec, libavformat, libavutil, libswscale
- 编解码器: H.264 (libx264)

**SDL2**:
- 版本: 2.26.x 或更新
- 用途: 视频渲染到 Qt widget

**PJSIP**:
- 当前项目使用的版本需确认
- 需启用: --enable-video, --with-ffmpeg, --with-sdl

### 1.3 架构设计

```
┌─────────────────────────────────────────┐
│           QML UI Layer                  │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐ │
│  │ Video   │  │ Call    │  │ Control │ │
│  │ Display │  │ Status  │  │ Buttons │ │
│  └─────────┘  └─────────┘  └─────────┘ │
└─────────────────────────────────────────┘
                    ↕
┌─────────────────────────────────────────┐
│      VideoCallManager (C++)             │
│  - 管理视频窗口和渲染                    │
│  - 控制视频设备（摄像头）                │
│  - 处理视频流                            │
└─────────────────────────────────────────┘
                    ↕
┌─────────────────────────────────────────┐
│          Risip SDK                      │
│  - RisipCall (音视频通话)                │
│  - RisipMedia (媒体控制)                 │
└─────────────────────────────────────────┘
                    ↕
┌─────────────────────────────────────────┐
│            PJSIP                        │
│  - pjsua (高层 API)                     │
│  - pjmedia_vid_dev (视频设备)           │
│  - pjmedia_codec (编解码)               │
└─────────────────────────────────────────┘
```

---

## 阶段 2：Windows 平台 - 编译依赖库

### 2.1 准备开发环境

**工具**:
- Visual Studio 2019/2022
- CMake 3.20+
- MSYS2 (for FFmpeg)
- Git

**环境变量**:
```
FFMPEG_ROOT=C:\ffmpeg
SDL2_ROOT=C:\SDL2
```

### 2.2 编译 FFmpeg for Windows

**步骤**:
1. 下载 FFmpeg 源码
   ```bash
   git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg
   cd ffmpeg
   git checkout release/6.0
   ```

2. 使用 MSYS2 配置
   ```bash
   ./configure \
     --prefix=/c/ffmpeg \
     --toolchain=msvc \
     --enable-shared \
     --disable-static \
     --enable-gpl \
     --enable-libx264 \
     --enable-decoder=h264 \
     --enable-encoder=libx264 \
     --disable-programs \
     --disable-doc
   ```

3. 编译
   ```bash
   make -j8
   make install
   ```

**产物**:
- `avcodec-60.dll`
- `avformat-60.dll`
- `avutil-58.dll`
- `swscale-7.dll`
- 对应的 `.lib` 和头文件

### 2.3 编译 SDL2 for Windows

**方案 A: 使用预编译二进制** (推荐)
1. 下载: https://github.com/libsdl-org/SDL/releases
2. 解压到 `C:\SDL2`
3. 包含: SDL2.dll, SDL2.lib, include/

**方案 B: 从源码编译**
```bash
git clone https://github.com/libsdl-org/SDL.git SDL2
cd SDL2
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=C:/SDL2
cmake --build . --config Release
cmake --install .
```

---

## 阶段 3：Windows 平台 - 重新编译 PJSIP

### 3.1 检查当前 PJSIP 配置

**文件位置**:
- 源码: `src/risip/pjproject/` (需要确认)
- 编译配置: `config_site.h`

### 3.2 修改 PJSIP 编译配置

**创建/修改 `pjlib/include/pj/config_site.h`**:
```c
/* 启用视频支持 */
#define PJMEDIA_HAS_VIDEO           1

/* FFmpeg 视频编解码 */
#define PJMEDIA_HAS_FFMPEG_VID_CODEC 1
#define PJMEDIA_HAS_FFMPEG_CODEC_H264 1

/* SDL 视频设备 */
#define PJMEDIA_VIDEO_DEV_HAS_SDL    1

/* 禁用不需要的编解码器 */
#define PJMEDIA_HAS_SPEEX_CODEC      0
#define PJMEDIA_HAS_GSM_CODEC        0

/* 性能优化 */
#define PJ_HAS_HIGH_RES_TIMER        1
```

### 3.3 配置 PJSIP 编译

**Windows (Visual Studio)**:
```bash
cd pjproject
./configure-vs \
  --enable-video \
  --with-ffmpeg=C:/ffmpeg \
  --with-sdl=C:/SDL2

# 或使用环境变量
set FFMPEG_ROOT=C:\ffmpeg
set SDL2_ROOT=C:\SDL2
./configure-vs --enable-video
```

### 3.4 编译 PJSIP

```bash
# 打开 Visual Studio 解决方案
pjproject-vs14.sln

# 或使用命令行
msbuild pjproject-vs14.sln /p:Configuration=Release /p:Platform=x64
```

**验证**:
- 检查是否生成 `pjmedia_videodev.lib`
- 运行 `pjsua-lib-test` 测试视频功能

---

## 阶段 4：Windows 平台 - 实现 C++ 视频管理类

### 4.1 创建 VideoCallManager 类

**文件**: `src/video/VideoCallManager.h`

```cpp
#ifndef VIDEOCALLMANAGER_H
#define VIDEOCALLMANAGER_H

#include <QObject>
#include <QQuickPaintedItem>

class VideoCallManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool hasLocalVideo READ hasLocalVideo NOTIFY hasLocalVideoChanged)
    Q_PROPERTY(bool hasRemoteVideo READ hasRemoteVideo NOTIFY hasRemoteVideoChanged)
    Q_PROPERTY(bool videoEnabled READ videoEnabled WRITE setVideoEnabled NOTIFY videoEnabledChanged)

public:
    explicit VideoCallManager(QObject *parent = nullptr);
    ~VideoCallManager();

    static VideoCallManager* instance();
    static void registerToQml();

    bool hasLocalVideo() const;
    bool hasRemoteVideo() const;
    bool videoEnabled() const;

public slots:
    // 视频控制
    void setVideoEnabled(bool enabled);
    void startVideoPreview();
    void stopVideoPreview();

    // 摄像头控制
    QStringList getVideoDevices();
    void setVideoDevice(int index);

    // 视频窗口
    void setLocalVideoWindow(QQuickPaintedItem* window);
    void setRemoteVideoWindow(QQuickPaintedItem* window);

signals:
    void hasLocalVideoChanged(bool has);
    void hasRemoteVideoChanged(bool has);
    void videoEnabledChanged(bool enabled);
    void videoError(const QString& error);

private:
    class Private;
    Private* d;
};

#endif
```

### 4.2 实现视频渲染

**创建 QML 视频组件**:
```cpp
class VideoRenderer : public QQuickPaintedItem
{
    Q_OBJECT
public:
    explicit VideoRenderer(QQuickItem* parent = nullptr);
    void paint(QPainter* painter) override;

public slots:
    void onFrameReceived(const QImage& frame);

private:
    QImage m_currentFrame;
    QMutex m_frameMutex;
};
```

### 4.3 集成 PJSIP 视频 API

**关键 API**:
```cpp
// 获取视频设备列表
pjsua_vid_dev_count()
pjsua_vid_dev_get_info()

// 视频窗口管理
pjsua_vid_win_id wid;
pjsua_vid_preview_param param;
pjsua_vid_preview_start(dev_id, &param);

// 通话中启用视频
pjsua_call_set_vid_strm(call_id, PJSUA_CALL_VID_STRM_ADD, &param);

// 视频流控制
pjsua_call_vid_stream_is_running(call_id, med_idx, &dir);
```

---

## 阶段 5：Windows 平台 - QML 视频界面

### 5.1 创建视频显示组件

**文件**: `src/qml/components/video/VideoDisplay.qml`

```qml
import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    color: "#000000"

    // 视频渲染区域
    VideoRenderer {
        id: videoRenderer
        anchors.fill: parent
    }

    // 无视频时的占位符
    Text {
        anchors.centerIn: parent
        text: "无视频信号"
        font.pixelSize: 16
        color: "#ffffff"
        visible: !videoRenderer.hasFrame
    }

    // 视频控制按钮
    Row {
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.margins: 10
        spacing: 10

        Button {
            text: VideoCallManager.videoEnabled ? "关闭视频" : "开启视频"
            onClicked: VideoCallManager.videoEnabled = !VideoCallManager.videoEnabled
        }

        Button {
            text: "切换摄像头"
            onClicked: switchCamera()
        }
    }
}
```

### 5.2 集成到 SIP 通话界面

**修改**: `src/qml/components/sip_phone/SipCallWindow.qml`

```qml
Column {
    spacing: 10

    // 远端视频（大窗口）
    VideoDisplay {
        width: 640
        height: 480
        videoSource: VideoCallManager.remoteVideo
    }

    // 本地视频（小窗口，Picture-in-Picture）
    VideoDisplay {
        width: 160
        height: 120
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10
        videoSource: VideoCallManager.localVideo
    }

    // 通话控制
    Row {
        Button {
            text: "挂断"
            onClicked: SipPhoneManager.hangupCall()
        }

        Button {
            text: videoEnabled ? "关闭视频" : "开启视频"
            onClicked: VideoCallManager.videoEnabled = !videoEnabled
        }
    }
}
```

---

## 阶段 6：Windows 平台 - 测试和调试

### 6.1 单元测试

**测试项目**:
- [ ] FFmpeg 编解码器初始化
- [ ] SDL2 视频显示
- [ ] 摄像头设备枚举和打开
- [ ] 本地视频预览
- [ ] H.264 编码/解码

### 6.2 集成测试

**测试场景**:
1. 单机视频预览
2. 与 SIP 服务器建立视频通话
3. 多个账户间视频通话
4. 视频通话中切换摄像头
5. 视频通话中启用/禁用视频

### 6.3 性能测试

**指标**:
- CPU 使用率 < 50%
- 内存占用 < 200MB
- 视频帧率 >= 25fps
- 视频延迟 < 200ms

### 6.4 兼容性测试

**测试设备**:
- [ ] 罗技 C920 摄像头
- [ ] 集成摄像头
- [ ] USB 摄像头

**分辨率**:
- [ ] 640x480 (VGA)
- [ ] 1280x720 (HD)
- [ ] 1920x1080 (Full HD)

---

## 阶段 7：AArch64 平台 - 交叉编译

### 7.1 准备交叉编译工具链

**安装**:
```bash
sudo apt install gcc-aarch64-linux-gnu g++-aarch64-linux-gnu
```

**环境变量**:
```bash
export CROSS_COMPILE=aarch64-linux-gnu-
export CC=${CROSS_COMPILE}gcc
export CXX=${CROSS_COMPILE}g++
export AR=${CROSS_COMPILE}ar
export RANLIB=${CROSS_COMPILE}ranlib
```

### 7.2 交叉编译 FFmpeg for AArch64

```bash
./configure \
  --prefix=/opt/ffmpeg-aarch64 \
  --enable-cross-compile \
  --cross-prefix=aarch64-linux-gnu- \
  --arch=aarch64 \
  --target-os=linux \
  --enable-shared \
  --disable-static \
  --enable-gpl \
  --enable-libx264 \
  --enable-decoder=h264 \
  --enable-encoder=libx264 \
  --disable-programs \
  --disable-doc

make -j8
make install
```

### 7.3 交叉编译 SDL2 for AArch64

```bash
mkdir build-aarch64 && cd build-aarch64
cmake .. \
  -DCMAKE_TOOLCHAIN_FILE=../cmake/aarch64-linux-gnu.cmake \
  -DCMAKE_INSTALL_PREFIX=/opt/SDL2-aarch64

make -j8
make install
```

### 7.4 交叉编译 PJSIP for AArch64

```bash
export FFMPEG_ROOT=/opt/ffmpeg-aarch64
export SDL2_ROOT=/opt/SDL2-aarch64

./configure \
  --host=aarch64-linux-gnu \
  --enable-video \
  --with-ffmpeg=$FFMPEG_ROOT \
  --with-sdl=$SDL2_ROOT

make dep
make -j8
```

---

## 阶段 8：AArch64 平台 - 测试和优化

### 8.1 部署到目标设备

**传输文件**:
```bash
scp -r bin/ libs/ root@192.168.1.100:/opt/belt_control/
```

**库依赖**:
```bash
ldd belt_control_system
# 确保所有依赖库都存在
```

### 8.2 硬件加速

**启用硬件编解码器** (如果支持):
- Rockchip: MPP (Media Process Platform)
- NXP i.MX: VPU
- Allwinner: CedarX

**修改 FFmpeg 配置**:
```c
// 使用硬件加速器
av_hwdevice_ctx_create(&hw_device_ctx, AV_HWDEVICE_TYPE_DRM, NULL, NULL, 0);
```

### 8.3 性能优化

**CPU 优化**:
- 使用 NEON 指令集
- 调整编码器预设 (preset=fast)
- 降低分辨率 (640x480)

**内存优化**:
- 使用 zero-copy buffer
- 减少帧缓冲数量

---

## 关键文件结构

```
belt_control_system/
├── src/
│   ├── video/
│   │   ├── VideoCallManager.h
│   │   ├── VideoCallManager.cpp
│   │   ├── VideoRenderer.h
│   │   └── VideoRenderer.cpp
│   ├── risip/
│   │   ├── core/
│   │   │   └── risipmedia.cpp (修改，添加视频支持)
│   │   └── pjsipwrapper/
│   │       └── pjsipcall.cpp (修改，视频通话)
│   └── qml/
│       └── components/
│           └── video/
│               ├── VideoDisplay.qml
│               └── VideoCallWindow.qml
├── libs/
│   ├── ffmpeg/
│   │   ├── windows-x64/
│   │   └── linux-aarch64/
│   ├── SDL2/
│   │   ├── windows-x64/
│   │   └── linux-aarch64/
│   └── pjsip/
│       ├── windows-x64/
│       └── linux-aarch64/
└── CMakeLists.txt (修改，添加视频模块)
```

---

## 风险和挑战

### 技术风险

1. **PJSIP 视频稳定性**
   - 风险: PJSIP 视频功能相对音频不够成熟
   - 缓解: 充分测试，准备 fallback 方案

2. **跨平台兼容性**
   - 风险: Windows 和 AArch64 行为差异
   - 缓解: 抽象层，平台特定代码隔离

3. **性能问题**
   - 风险: AArch64 设备性能有限
   - 缓解: 硬件加速，优化编码参数

### 开发风险

1. **编译依赖复杂**
   - 风险: FFmpeg/SDL2 编译失败
   - 缓解: 使用预编译库，提供详细文档

2. **调试困难**
   - 风险: 视频问题难以定位
   - 缓解: 详细日志，分阶段测试

---

## 时间估算

| 阶段 | 任务 | 预计时间 |
|-----|-----|---------|
| 1 | 调研和规划 | 1天 |
| 2 | 编译依赖库 (Windows) | 2-3天 |
| 3 | 重新编译 PJSIP (Windows) | 1-2天 |
| 4 | 实现 C++ 视频管理类 | 3-4天 |
| 5 | 实现 QML 界面 | 2-3天 |
| 6 | 测试和调试 (Windows) | 3-4天 |
| 7 | 交叉编译 (AArch64) | 2-3天 |
| 8 | 测试和优化 (AArch64) | 2-3天 |
| **总计** | | **16-25天** |

---

## 下一步行动

### 立即执行 (阶段 1)

1. ✅ 创建此实施计划文档
2. [ ] 检查现有 PJSIP 源码位置和版本
3. [ ] 分析 Risip SDK 中的视频相关代码
4. [ ] 研究 pjsip-apps/vidgui 示例
5. [ ] 确定 FFmpeg 和 SDL2 版本

### 准备阶段 2

1. [ ] 安装 MSYS2
2. [ ] 准备 FFmpeg 和 SDL2 源码
3. [ ] 创建编译脚本

---

**文档状态**: 初稿完成
**最后更新**: 2025-12-03 16:30
**负责人**: Claude (AI Assistant)
**审核人**: 用户 (待审核)
