# 远程视频卡顿问题 - Push 模式重构方案

**问题日期**: 2025-12-10
**当前状态**: 🔄 设计完成,待实现

---

## 问题分析

### 症状
从日志统计看到:
```
📊 [REMOTE VIDEO STATS] Captured FPS: "9.7" | Avg interval: "114.9" ms
📊 [REMOTE VIDEO STATS] Captured FPS: "3.2" | Avg interval: "316.0" ms
📊 [REMOTE VIDEO STATS] Captured FPS: "2.8" | Avg interval: "363.5" ms
📊 [REMOTE VIDEO STATS] Captured FPS: "2.4" | Avg interval: "423.0" ms
```

实际只捕获到 **2-10 FPS**,远低于对方发送的 60fps!画面一帧一帧播放,严重卡顿。

### 根本原因

**错误架构**: 使用定时器(33ms)主动拉取帧(Pull 模式)

```cpp
// ❌ 错误的 Pull 模式
m_captureTimer->setInterval(33);  // 固定 30fps
connect(m_captureTimer, &QTimer::timeout, this, &RemoteVideoManager::captureVideoFrame);

void RemoteVideoManager::captureVideoFrame()
{
    // 主动去 pull 帧
    pj_status_t status = pjmedia_port_get_frame(m_videoPort, &frame);
    // ...
}
```

**问题**:
1. 定时器频率固定,无法适应可变帧率(30/60fps)
2. Pull 模式可能在帧未就绪时调用,导致丢帧
3. 不符合 PJSIP 的事件驱动架构

---

## 正确架构: 事件驱动的 Push 模式

PJSIP 内部使用 video conference bridge 来路由视频流:

```
[Decoder Port] --> [Video Conference Bridge] --> [Renderer Port]
     ↓                                                 ↓
  解码后的帧                                    主动推送(put_frame)
```

PJSIP 日志中可以看到:
```
Port 3 (vstdec...) transmitting to port 2 (SDL renderer)
```

SDL renderer 不是用定时器拉取帧,而是实现了 `put_frame` 回调,让 PJSIP 主动推送!

---

## 实现方案

### 1. 创建自定义 pjmedia_port

```cpp
// 定义自定义 port
pjmedia_port *m_customPort;

// 分配并初始化
m_customPort = (pjmedia_port*)pj_pool_zalloc(m_pool, sizeof(pjmedia_port));

// 设置回调
m_customPort->put_frame = &RemoteVideoManager::port_put_frame;  // ✅ 关键!
m_customPort->get_frame = &RemoteVideoManager::port_get_frame;
m_customPort->port_data.pdata = this;  // 存储 this 指针
```

### 2. 连接到 Video Conference Bridge

```cpp
// 添加自定义 port 到 video conference
pjsua_vid_conf_port_id custom_slot;
pjsua_vid_conf_add_port(m_pool, m_customPort, NULL, &custom_slot);

// 连接: decoder -> custom_port
pjsua_vid_conf_port_id decoder_slot = call_med->strm.v.rdr_slot;
pjsua_vid_conf_connect(decoder_slot, custom_slot, NULL);
```

### 3. 实现 put_frame 回调 (Push 模式)

```cpp
// ✅ PJSIP 在收到新帧时主动调用
pj_status_t RemoteVideoManager::port_put_frame(pjmedia_port *port, pjmedia_frame *frame)
{
    RemoteVideoManager *self = static_cast<RemoteVideoManager*>(port->port_data.pdata);

    if (frame->type == PJMEDIA_FRAME_TYPE_VIDEO) {
        // 立即处理帧,无需等待定时器!
        self->onFrameReceived(frame, &port->info.fmt);
    }

    return PJ_SUCCESS;
}

void RemoteVideoManager::onFrameReceived(pjmedia_frame *frame, const pjmedia_format *fmt)
{
    // 转换为 QVideoFrame
    QVideoFrame videoFrame = convertPjFrameToQt(frame, fmt);

    // 发送到 Qt 主线程显示
    emit frameReadyForDisplay(videoFrame);
}
```

### 4. 线程安全处理

```cpp
// PJSIP 线程 -> Qt 主线程
connect(this, &RemoteVideoManager::frameReadyForDisplay,
        this, &RemoteVideoManager::displayFrame,
        Qt::QueuedConnection);  // ✅ 跨线程信号

void RemoteVideoManager::displayFrame(QVideoFrame frame)
{
    // 在 Qt 主线程执行
    m_videoSink->setVideoFrame(frame);
}
```

---

## 架构对比

### ❌ 旧架构 (Pull 模式)

```
Qt Timer (33ms 固定)
  ↓
captureVideoFrame()
  ↓
pjmedia_port_get_frame()  ← 主动拉取
  ↓
convertPjFrameToQt()
  ↓
m_videoSink->setVideoFrame()
```

**问题**:
- 固定频率,无法适应可变帧率
- 可能在帧未就绪时拉取
- 实际只能达到 2-10 FPS

### ✅ 新架构 (Push 模式)

```
PJSIP Video Bridge
  ↓ (新帧到达)
port_put_frame() 回调  ← PJSIP 主动推送
  ↓
onFrameReceived()
  ↓ (emit信号,跨线程)
displayFrame() [Qt主线程]
  ↓
m_videoSink->setVideoFrame()
```

**优势**:
- 事件驱动,实时响应
- 自动适应任何帧率(30/60/120fps)
- 无丢帧,无延迟
- 符合 PJSIP 设计哲学

---

## 文件修改清单

### src/sip_phone/RemoteVideoManager.h

**新增成员变量**:
```cpp
pjmedia_port *m_customPort;        // 自定义 port
pj_pool_t *m_pool;                 // PJSIP 内存池
unsigned m_videoMediaIndex;        // 视频媒体索引
```

**新增方法**:
```cpp
// PJSIP 回调
void onFrameReceived(pjmedia_frame *frame, const pjmedia_format *fmt);

// Bridge 连接管理
bool detectAndConnectToVideoBridge();
void disconnectFromVideoBridge();

// Port 管理
bool createCustomPort();
void destroyCustomPort();

// 静态 C 回调
static pj_status_t port_put_frame(pjmedia_port *port, pjmedia_frame *frame);
static pj_status_t port_get_frame(pjmedia_port *port, pjmedia_frame *frame);
static pj_status_t port_on_destroy(pjmedia_port *port);
```

**删除**:
```cpp
QTimer *m_captureTimer;         // ❌ 不再需要捕获定时器
void captureVideoFrame();       // ❌ 不再需要主动拉取
```

### src/sip_phone/RemoteVideoManager.cpp

**完全重写**,实现事件驱动架构。

---

## 实现步骤

1. ✅ **设计新架构** - 已完成
2. ✅ **更新头文件** - [RemoteVideoManager.h](src/sip_phone/RemoteVideoManager.h) 已更新
3. ⏳ **重写实现文件** - 待执行
   - 由于文件较大(404行),需要完全重写
   - 已备份旧版本: `RemoteVideoManager.cpp.backup_pull_mode`
4. ⏳ **编译测试**
5. ⏳ **性能验证**

---

## 预期效果

### 旧版本 (Pull 模式)
```
📊 [REMOTE VIDEO STATS] Captured FPS: "2.8" | Avg interval: "363.5" ms
```

### 新版本 (Push 模式)
```
📊 [REMOTE VIDEO PUSH] Received FPS: "60.0" | Avg interval: "16.7" ms  ← 目标!
```

完全消除卡顿,实现流畅的 60fps 视频播放!

---

## 下一步

请先关闭应用程序,然后我会:
1. 完整重写 `RemoteVideoManager.cpp` 实现 Push 模式
2. 编译测试
3. 验证性能提升

**关键**: 这是正确的架构,符合 PJSIP 的设计原则!

---

**备注**:
- 旧代码已备份到 `src/sip_phone/RemoteVideoManager.cpp.backup_pull_mode`
- 头文件已更新,定义了新的 API
- 实现文件需要完全重写以实现 Push 架构
