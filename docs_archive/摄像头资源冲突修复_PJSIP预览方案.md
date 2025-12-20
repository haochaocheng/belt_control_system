# 摄像头资源冲突修复 - PJSIP预览方案

## 📋 问题描述

**症状**: 视频通话时，本地预览正常显示，但远端看到的画面是冻结的（只显示第一帧）

**日志证据**:
```
TX pt=100, size=720x480, fps=15.00, last update:00h:00m:03.779s ago
🎞️ VideoSinkItem rendered 540 frames
```
- PJSIP停止发送新的视频帧（3.779秒前最后一次发送）
- Qt本地预览继续渲染（540帧）

**根本原因**: **摄像头资源冲突**
1. Qt Multimedia 的 `QCamera` 独立启动并控制摄像头用于本地预览
2. PJSIP 也需要访问同一个摄像头来捕获帧并发送给对方
3. 同一个物理摄像头不能被两个进程同时独占控制
4. Qt 抢先获得摄像头控制权，PJSIP 无法访问摄像头
5. 结果：本地预览正常（Qt有摄像头），远端看到冻结画面（PJSIP无法访问摄像头）

---

## ✅ 解决方案：使用PJSIP预览代替Qt独立控制

**核心思路**:
- 不再使用 Qt Multimedia 的 QCamera 独立控制摄像头
- 改为使用 PJSIP 的视频预览功能 (`pjsua_vid_preview_start`)
- 从 PJSIP 的预览端口获取视频帧，通过 Qt Multimedia 的 QVideoSink 显示在 QML 中
- **PJSIP 独占摄像头**，同时用于：
  1. 本地预览（通过我们的 LocalVideoManager）
  2. 发送给远端（PJSIP内部处理）

---

## 🔧 实现细节

### 1. 新增 `LocalVideoManager` 类

**作用**: 从 PJSIP 预览获取视频帧，通过 QVideoSink 提供给 QML 显示

**文件**:
- `src/sip_phone/LocalVideoManager.h`
- `src/sip_phone/LocalVideoManager.cpp`

**关键方法**:
```cpp
// 启动 PJSIP 视频预览
void LocalVideoManager::startPreview()
{
    // 使用 PJSIP API 启动预览（PJSIP控制摄像头）
    pjsua_vid_preview_start(PJMEDIA_VID_DEFAULT_CAPTURE_DEV, &param);

    // 获取预览窗口ID
    m_previewWinId = pjsua_vid_preview_get_win(PJMEDIA_VID_DEFAULT_CAPTURE_DEV);

    // 附加到预览端口
    attachPreviewPort();

    // 启动30fps帧捕获定时器
    m_captureTimer->start();
}

// 从 PJSIP 预览端口获取帧
void LocalVideoManager::capturePreviewFrame()
{
    // 从 pjmedia_port 获取视频帧
    pjmedia_port_get_frame(m_previewPort, &frame);

    // 转换为 QVideoFrame
    QVideoFrame videoFrame = convertPjFrameToQt(&frame, fmt);

    // 发送到 QVideoSink (Qt渲染)
    m_videoSink->setVideoFrame(videoFrame);
}
```

**关键特性**:
- 使用 `pjsua_vid_preview_start()` 让 PJSIP 启动和控制摄像头
- 从 `pjmedia_port` 获取原始视频帧（与RemoteVideoManager相同的方式）
- 支持 YUV420P 格式（让Qt自动处理颜色转换）
- 30fps 帧捕获定时器

---

### 2. 集成到 `SipPhoneManager`

**修改文件**: `src/sip_phone/SipPhoneManager.h` 和 `src/sip_phone/SipPhoneManager.cpp`

**添加的内容**:
```cpp
// SipPhoneManager.h - 新增属性
Q_PROPERTY(QObject* localVideoManager READ localVideoManager CONSTANT)
QObject* localVideoManager() const;

// SipPhoneManager.cpp - 私有成员
class Private {
    LocalVideoManager *localVideoManager;  // 本地视频管理器（PJSIP预览）
};

// SipPhoneManager.cpp - 构造函数
Private(SipPhoneManager *parent) {
    localVideoManager = new LocalVideoManager(parent);
}

// SipPhoneManager.cpp - 实现getter
QObject* SipPhoneManager::localVideoManager() const {
    return d->localVideoManager;
}
```

---

### 3. 更新 QML 界面 (`SipDialPage.qml`)

**核心更改**: 将所有对 `qtVideoPreview` 的引用改为 `localVideoManager`

**修改点**:

#### (1) 自动启动预览（视频通话开始时）
```qml
// ✅ 视频通话时自动启动 PJSIP 本地视频预览（不使用 Qt Camera）
function onIsInCallChanged() {
    if (SipPhoneManager.isInCall && !videoPreviewButton.previewActive) {
        console.log("✅ Video call started - auto-starting PJSIP local video preview")
        SipPhoneManager.localVideoManager.startPreview()  // 改为 localVideoManager
        videoPreviewButton.previewActive = true
    } else if (!SipPhoneManager.isInCall && videoPreviewButton.previewActive) {
        console.log("✅ Call ended - auto-stopping PJSIP local video preview")
        SipPhoneManager.localVideoManager.stopPreview()
        videoPreviewButton.previewActive = false
    }
}
```

#### (2) VideoSinkItem 连接
```qml
VideoSinkItem {
    id: videoDisplay
    Component.onCompleted: {
        // 连接到 PJSIP local video manager 的 video sink
        if (SipPhoneManager && SipPhoneManager.localVideoManager) {
            sink = SipPhoneManager.localVideoManager.videoSink  // 改为 localVideoManager
        }
    }
}
```

#### (3) 手动预览按钮
```qml
onClicked: {
    if (videoPreviewButton.previewActive) {
        SipPhoneManager.localVideoManager.stopPreview()  // 改为 localVideoManager
        videoPreviewButton.previewActive = false
    } else {
        SipPhoneManager.localVideoManager.startPreview()  // 改为 localVideoManager
        videoPreviewButton.previewActive = true
    }
}
```

---

### 4. 更新构建配置 (`CMakeLists.txt`)

**文件**: `src/sip_phone/CMakeLists.txt`

**添加**:
```cmake
add_library(sip_phone_module STATIC
    ...
    LocalVideoManager.h
    LocalVideoManager.cpp
    ...
)
```

---

## 📊 架构对比

### ❌ 旧方案（摄像头冲突）
```
┌─────────────────────────────────┐
│  Qt Multimedia (QCamera)        │  ← 独立控制摄像头
│  └→ 本地预览 (VideoSinkItem)    │
└─────────────────────────────────┘
                ⚠️ 冲突！ ⚠️
┌─────────────────────────────────┐
│  PJSIP                          │  ← 无法访问摄像头
│  └→ 发送给远端（冻结）          │
└─────────────────────────────────┘
```

### ✅ 新方案（PJSIP独占）
```
┌───────────────────────────────────────────┐
│  PJSIP (独占摄像头)                       │
│  ├→ 本地预览端口                          │
│  │  └→ LocalVideoManager                  │
│  │     └→ QVideoSink → VideoSinkItem      │
│  └→ 编码器 → 发送给远端 ✅                │
└───────────────────────────────────────────┘
```

---

## 🧪 测试要点

### 1. 本地视频预览
- [ ] 启动应用后点击"本机预览"按钮，本地视频正常显示
- [ ] 视频颜色正常（不泛红、不模糊）
- [ ] 帧率流畅（30fps）

### 2. 视频通话
- [ ] 拨打视频通话，自动启动本地预览
- [ ] 本地和远端视频左右并排显示
- [ ] **远端能看到持续更新的视频（不冻结）** ← 关键测试点
- [ ] 通话结束后自动停止本地预览

### 3. PJSIP 日志验证
```
期望日志：
✅ LocalVideoManager created (PJSIP preview mode)
✅ LocalVideoManager: PJSIP preview started successfully
📺 LocalVideoManager: Attached to preview port via vp_cap
📹 LocalVideoManager: Captured 30 frames, format: Format_YUV420P size: QSize(640, 480)

PJSIP 发送统计（通话期间应该持续更新）：
TX pt=100, size=720x480, fps=15.00, last update:00h:00m:00.100s ago  ← 应该是最近（<1秒）
```

---

## 🎯 修复效果

### 修复前
- ❌ 本地预览：正常 ✅
- ❌ 远端看到的画面：冻结（只有第一帧）
- ❌ PJSIP TX统计：`last update:00h:00m:03.779s ago`（停止发送）

### 修复后（预期）
- ✅ 本地预览：正常 ✅
- ✅ 远端看到的画面：持续更新 ✅
- ✅ PJSIP TX统计：`last update:00h:00m:00.100s ago`（持续发送）

---

## 🔍 技术要点

### 1. PJSIP 视频预览 API
```cpp
// 启动预览
pjsua_vid_preview_start(PJMEDIA_VID_DEFAULT_CAPTURE_DEV, &param);

// 获取预览窗口ID
pjsua_vid_win_id win_id = pjsua_vid_preview_get_win(PJMEDIA_VID_DEFAULT_CAPTURE_DEV);

// 获取预览窗口信息
pjsua_vid_win_info wi;
pjsua_vid_win_get_info(win_id, &wi);

// 访问预览端口（通过内部结构）
pjsua_vid_win *win = &pjsua_var.win[win_id];
pjmedia_port *port = pjmedia_vid_port_get_passive_port(win->vp_cap);
```

### 2. 视频帧转换
```cpp
// 支持 YUV420P 格式（与 RemoteVideoManager 相同）
QVideoFrameFormat format(QSize(width, height), QVideoFrameFormat::Format_YUV420P);
QVideoFrame videoFrame(format);

// 复制 Y、U、V 平面
memcpy(videoFrame.bits(0), src_y, width * height);
memcpy(videoFrame.bits(1), src_u, width * height / 4);
memcpy(videoFrame.bits(2), src_v, width * height / 4);
```

### 3. 线程安全
- LocalVideoManager 的定时器在 Qt 主线程中运行（与 RemoteVideoManager 相同的模式）
- 帧捕获在 Qt 主线程中进行（33ms间隔，30fps）

---

## 📝 总结

**问题**: Qt Multimedia 和 PJSIP 同时控制摄像头导致资源冲突

**解决**: 让 PJSIP 独占摄像头，Qt 只负责显示（不控制摄像头）

**核心改变**:
- ❌ 移除：Qt Multimedia QCamera 独立控制摄像头
- ✅ 新增：LocalVideoManager 从 PJSIP 预览获取帧
- ✅ 效果：PJSIP 可以同时用摄像头做预览和发送

**编译状态**: ✅ 成功编译 (2025-12-08 13:02)

**下一步**: 测试视频通话，验证远端能看到持续更新的视频
