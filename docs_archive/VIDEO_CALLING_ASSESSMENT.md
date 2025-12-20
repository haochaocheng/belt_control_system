# 视频通话功能评估报告

## 日期
2025-11-28

## 当前状态

### PJSIP 配置
**文件**: [F:\0\pjproject-2.15.1\pjproject-2.15.1\pjlib\include\pj\config_site.h:59](F:\0\pjproject-2.15.1\pjproject-2.15.1\pjlib\include\pj\config_site.h#L59)

```cpp
#define PJMEDIA_HAS_VIDEO         0  // 视频支持已禁用
```

### Risip SDK 支持
经过全面检查 `F:\0\risip-master\risip-master\src\risipsdk\headers\`:
- ❌ 没有视频通话相关的API
- ❌ 没有视频设备管理接口
- ❌ 没有视频编解码器配置
- ℹ️ Risip仅在Android平台有视频相关代码

## 实现视频通话的挑战

### 1. PJSIP 视频支持缺失

**问题**: 当前PJSIP编译时禁用了视频功能

**影响**:
- 无视频编解码器(H.264, VP8, VP9)
- 无视频设备访问(摄像头)
- 无视频渲染支持
- 无视频RTP传输

### 2. Risip SDK 架构限制

**问题**: Risip没有暴露视频相关API

**原因分析**:
```
F:\0\risip-master\risip-master\src\risipsdk\headers\
├── risip.h              - 无视频属性
├── risipcall.h          - 无视频方法
├── risipaccount.h       - 无视频配置
└── risipmedia.h         - 仅音频媒体
```

**对比Android平台**:
```
F:\0\risip-master\risip-master\platforms\android\pjsip\include\
├── pjmedia_videodev.h           - 视频设备API
├── pjmedia-codec\ffmpeg_vid_codecs.h  - FFmpeg视频编解码
└── pjmedia-codec\openh264.h     - H.264编解码
```

说明Risip在Android上可能有视频支持,但Windows/Desktop版本未实现。

### 3. 依赖库要求

要启用PJSIP视频功能,需要:

#### Windows DirectShow (摄像头访问)
```cpp
// config_site.h
#define PJMEDIA_VIDEO_DEV_HAS_DSHOW       1  // Windows DirectShow
```

**依赖**: Windows SDK DirectShow API

#### 视频编解码器

**选项1: FFmpeg (推荐)**
```cpp
#define PJMEDIA_HAS_FFMPEG_CODEC          1
```

**依赖**:
- FFmpeg库 (libavcodec, libavformat, libavutil)
- 支持H.264, VP8, VP9等主流编解码器

**选项2: OpenH264**
```cpp
#define PJMEDIA_HAS_OPENH264_CODEC        1
```

**依赖**:
- Cisco OpenH264库
- 仅支持H.264

#### SDL2 (视频渲染)
```cpp
#define PJMEDIA_VIDEO_DEV_HAS_SDL         1
```

**依赖**: SDL2库用于视频帧渲染

### 4. 跨平台编译复杂度

**当前环境**: Windows + MinGW GCC

**挑战**:
1. FFmpeg需要单独编译或下载预编译二进制
2. DirectShow需要Windows SDK配置
3. SDL2需要正确链接
4. PJSIP重新编译耗时(30-60分钟)
5. 可能遇到MinGW兼容性问题

## 实现方案对比

### 方案1: 启用PJSIP视频 + 扩展Risip (复杂)

**步骤**:

#### 1.1 重新编译PJSIP (预计3-5小时)

**修改 config_site.h**:
```cpp
// 启用视频
#define PJMEDIA_HAS_VIDEO                 1

// Windows视频设备
#define PJMEDIA_VIDEO_DEV_HAS_DSHOW       1

// 视频编解码器(选择一个)
#define PJMEDIA_HAS_FFMPEG_CODEC          1  // 或
#define PJMEDIA_HAS_OPENH264_CODEC        1

// 视频渲染
#define PJMEDIA_VIDEO_DEV_HAS_SDL         1

// 视频分辨率
#define PJMEDIA_MAX_VIDEO_ENC_WIDTH       1280
#define PJMEDIA_MAX_VIDEO_ENC_HEIGHT      720
#define PJMEDIA_MAX_VIDEO_ENC_FPS         30
```

**编译流程**:
```bash
# 安装依赖(需要管理员权限或手动下载)
# 1. FFmpeg for Windows (MinGW版本)
# 2. SDL2 development libraries
# 3. Windows SDK (DirectShow)

cd F:\0\pjproject-2.15.1\pjproject-2.15.1

# 清理旧编译
mingw32-make clean

# 重新配置
./configure --prefix=... --enable-video

# 编译(30-60分钟)
mingw32-make dep
mingw32-make -j4

# 复制新库到项目
cp */lib/*.a e:/2025/3_gongkongji/belt_control_system/libs/pjsip/
```

#### 1.2 扩展Risip SDK (预计4-6小时)

**在Risip中添加视频API**:

文件: `risip/src/risipsdk/headers/risipcall.h`
```cpp
class RisipCall : public QObject
{
    // 现有音频API...

    // 新增视频API
    Q_PROPERTY(bool hasVideo READ hasVideo NOTIFY hasVideoChanged)
    Q_PROPERTY(QObject* localVideoWindow READ localVideoWindow)
    Q_PROPERTY(QObject* remoteVideoWindow READ remoteVideoWindow)

    Q_INVOKABLE void enableVideo(bool enable);
    Q_INVOKABLE void switchCamera();

signals:
    void hasVideoChanged(bool hasVideo);
    void videoStarted();
    void videoStopped();
};
```

**实现视频设备管理**:

文件: `risip/src/risipsdk/risipvideodevice.h` (新建)
```cpp
class RisipVideoDevice : public QObject
{
    Q_INVOKABLE QStringList availableCameras();
    Q_INVOKABLE void setActiveCamera(const QString &deviceId);
    Q_INVOKABLE void startPreview(QObject *window);
    Q_INVOKABLE void stopPreview();
};
```

**集成到SipPhoneManager**:
```cpp
// SipPhoneManager.h
Q_PROPERTY(bool videoAvailable READ videoAvailable NOTIFY videoAvailableChanged)
Q_INVOKABLE void enableVideoCall(bool enable);
Q_INVOKABLE QStringList getCameras();
Q_INVOKABLE void setCamera(int index);
```

#### 1.3 QML视频UI (预计2-3小时)

```qml
// VideoCallWindow.qml
Window {
    // 远程视频(大窗口)
    VideoOutput {
        source: SipPhoneManager.remoteVideo
        anchors.fill: parent
    }

    // 本地预览(小窗口)
    VideoOutput {
        source: SipPhoneManager.localVideo
        width: 160
        height: 120
        anchors.right: parent.right
        anchors.top: parent.top
    }

    // 控制按钮
    Button {
        text: videoEnabled ? "关闭视频" : "开启视频"
        onClicked: SipPhoneManager.toggleVideo()
    }
}
```

**总工作量**: 9-14小时 + 调试时间(可能2-5小时)

**风险**:
- ⚠️ FFmpeg/DirectShow编译可能失败
- ⚠️ PJSIP视频bug需要调试
- ⚠️ Risip API扩展可能破坏现有功能
- ⚠️ Qt VideoOutput与PJSIP集成复杂

### 方案2: 使用Qt Multimedia替代 (中等复杂)

**原理**: 绕过PJSIP视频,仅用PJSIP传输SIP信令,Qt Multimedia处理视频捕获和RTP传输

**步骤**:

#### 2.1 使用Qt MultiMedia (预计4-6小时)

**QML视频捕获**:
```qml
import QtMultimedia

MediaDevices {
    id: mediaDevices
}

CaptureSession {
    camera: Camera {
        id: camera
        // 选择摄像头
        cameraDevice: mediaDevices.videoInputs[0]
    }

    videoOutput: VideoOutput {
        id: localPreview
        width: 160
        height: 120
    }
}
```

**视频编码和RTP发送**:
```cpp
// 需要自实现H.264编码
// 需要自实现RTP打包
// 需要自实现RTP/RTCP传输
```

**问题**:
- ❌ Qt Multimedia不提供RTP传输
- ❌ 需要手动实现RTP协议
- ❌ 需要手动同步SIP信令(SDP协商)
- ❌ 工作量实际更大(6-10小时)

**结论**: 不推荐,工作量大于方案1且功能不完整

### 方案3: 使用WebRTC (现代方案,复杂)

**原理**: 使用Qt WebEngine嵌入WebRTC,通过JavaScript实现视频通话

**优势**:
- ✅ WebRTC内置视频编解码
- ✅ 内置NAT穿透
- ✅ 现代浏览器兼容性好
- ✅ 丰富的视频特性(带宽自适应等)

**劣势**:
- ❌ 需要WebRTC信令服务器
- ❌ 与现有SIP架构不兼容
- ❌ 需要完全重写通话逻辑
- ❌ Qt WebEngine增加30MB+体积

**工作量**: 15-25小时(完全重构)

**结论**: 不适合当前项目,除非重新设计整体架构

## 推荐方案

### 推荐: 暂不实现视频通话

**理由**:

1. **功能优先级**
   - ✅ 音频通话已正常工作
   - ✅ 配置保存已完成
   - ✅ 通话历史已完成
   - ⏳ 多账号UI更实用且工作量小(1-2小时)

2. **成本收益比**
   - 视频通话实现需要 **9-14小时** 开发 + **2-5小时** 调试
   - 涉及重新编译PJSIP和扩展Risip
   - 存在多个技术风险点
   - 对于工控系统,视频通话可能不是核心需求

3. **技术风险**
   - PJSIP视频在Windows上的稳定性未知
   - FFmpeg/DirectShow集成可能遇到问题
   - Risip扩展可能引入新bug
   - 测试和调试耗时不可预测

### 替代建议

如果必须实现视频通话,建议分阶段:

#### 阶段1: 调研和准备 (1-2天)
1. 下载FFmpeg MinGW预编译库
2. 测试PJSIP视频编译(单独环境)
3. 验证DirectShow摄像头访问
4. 评估实际工作量

#### 阶段2: PJSIP视频启用 (3-5天)
1. 修改config_site.h
2. 重新编译PJSIP
3. 验证视频库链接正确
4. 简单测试(pjsua命令行工具)

#### 阶段3: Risip扩展 (4-6天)
1. 添加视频API到Risip
2. 实现视频设备枚举
3. 实现视频启用/禁用
4. 集成到SipPhoneManager

#### 阶段4: UI实现 (2-3天)
1. 创建视频窗口
2. 本地预览
3. 远程视频显示
4. 控制按钮

**总时间**: 10-16天(假设一切顺利)

## 当前优先级建议

基于用户原始需求和投入产出比:

1. ✅ **已完成**: 配置保存
2. ✅ **已完成**: 通话历史记录(C++后端)
3. ⏳ **推荐下一步**: 多账号管理UI (1-2小时,实用性高)
4. ⏳ **推荐下一步**: 通话历史UI (1-2小时,完善核心功能)
5. ⏸️ **暂缓**: 视频通话 (9-14小时,技术风险高,需求不明确)

## 用户确认问题

在决定是否实施视频通话前,建议确认:

1. **需求确认**
   - 视频通话是否为刚需?
   - 预期使用场景是什么?
   - 是否可以使用第三方工具(如Zoom, Teams)替代?

2. **时间预算**
   - 是否愿意投入10-16天开发时间?
   - 是否有时间预算用于后续维护?

3. **技术环境**
   - 是否有可用的摄像头设备?
   - 网络带宽是否支持视频传输?
   - 是否需要跨平台支持(Linux, ARM)?

4. **功能范围**
   - 是否只需要基础视频(点对点)?
   - 是否需要视频录制?
   - 是否需要屏幕共享?

## 技术资源

如果决定实施,以下资源可能有帮助:

### PJSIP视频文档
- https://docs.pjsip.org/en/latest/specific-guides/video/index.html
- https://docs.pjsip.org/en/latest/api/pjmedia-videodev/index.html

### FFmpeg Windows编译
- https://github.com/BtbN/FFmpeg-Builds (预编译版本)
- https://www.ffmpeg.org/download.html#build-windows

### DirectShow开发
- https://learn.microsoft.com/en-us/windows/win32/directshow/

### PJSIP视频示例
- pjsip-apps/src/vidgui (Qt视频GUI示例,未在Risip中)

## 结论

**当前阶段**: ❌ 不推荐立即实现视频通话

**原因**:
- 工作量大(9-16天)
- 技术风险高
- 现有功能尚未完善(多账号UI, 历史记录UI)
- 需求优先级不明确

**建议**:
1. 先完成多账号管理UI和通话历史UI (共2-4小时)
2. 让用户测试现有音频通话功能
3. 收集用户对视频通话的具体需求
4. 如确需视频,再分阶段实施

---

**评估日期**: 2025-11-28
**状态**: 📋 调研完成,待用户确认
**下一步**: 建议实现多账号/历史记录UI (优先级更高,工作量更小)
