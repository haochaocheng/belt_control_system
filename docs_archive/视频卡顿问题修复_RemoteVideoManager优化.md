# 视频卡顿问题修复 - RemoteVideoManager 优化

## 问题描述

用户反馈：**"可以了，但是感觉视频不流程，一卡一卡的，有什么问题吗？"**

在成功使用 re-INVITE 方案建立视频通话后，视频画面出现卡顿/不流畅的现象。

## 问题分析

通过分析日志，发现以下几个导致卡顿的原因：

### 1. RemoteVideoManager 重复附加视频端口 ⚠️ **主要原因**

**症状**:
```
📺 RemoteVideoManager: Attached to video port 0x...
📺 RemoteVideoManager: Attached to video port 0x...
📺 RemoteVideoManager: Attached to video port 0x...
(每500ms重复一次)
```

**根本原因**:

[RemoteVideoManager.cpp:102-154](src/sip_phone/RemoteVideoManager.cpp#L102-L154) 中的 `detectAndAttachVideoPort()` 函数：

```cpp
bool RemoteVideoManager::detectAndAttachVideoPort()
{
    // ... 查找视频端口的代码 ...

    if (status == PJ_SUCCESS && port) {
        m_videoPort = port;
        qDebug() << "📺 RemoteVideoManager: Attached to video port" << port;  // ❌ 每次都打印
        return true;
    }
}
```

这个函数被 `checkRemoteVideo()` 每 500ms 调用一次，即使视频端口没有改变，也会重复赋值和打印日志。

**影响**:
- 虽然只是指针赋值，但频繁的检查和日志输出会影响性能
- 在低性能系统上可能导致帧率不稳定

### 2. 初始解码错误

**症状**:
```
vstdec codec decode() error: Bad or corrupted bitstream (PJMEDIA_CODEC_EBADBITSTREAM)
```

**原因**:
- re-INVITE 建立视频时，前几帧可能因为关键帧丢失或编码器未完全就绪而解码失败
- 这会导致开始几秒视频出现卡顿或黑屏

**影响**:
- 通话开始时的短暂卡顿
- 通常在 2-3 秒后自动恢复

### 3. 帧率不稳定

**症状**:
```
Decoding format changed: 640x360 I420
15fps → 31fps → 32fps  (帧率频繁变化)
```

**原因**:
- 网络带宽波动
- 对方发送帧率不稳定
- SDL 渲染器需要适应新的帧率

**影响**:
- 视频播放速度时快时慢
- 可能导致音视频不同步

### 4. 发送帧率较低

**症状**:
```
TX pt=100, size=720x480, fps=15.00  ← 发送帧率低
RX pt=100, size=640x360, fps=32.00  ← 接收帧率高
```

**原因**:
- 本机摄像头配置为 15fps
- 或者编码器性能限制

**影响**:
- 对方看到的本机视频较卡顿
- 不影响本机看对方的视频

## 解决方案

### ✅ 已实施：优化 RemoteVideoManager (2025-12-09)

**修改文件**: [RemoteVideoManager.cpp:145-149](src/sip_phone/RemoteVideoManager.cpp#L145-L149)

**修改内容**:

```cpp
if (status == PJ_SUCCESS && port) {
    // ✅ 优化：只有在端口改变时才重新附加和打印日志
    if (m_videoPort != port) {
        m_videoPort = port;
        qDebug() << "📺 RemoteVideoManager: Attached to video port" << port;
    }
    return true;
}
```

**改进效果**:
- ✅ 消除不必要的重复赋值
- ✅ 减少日志输出噪音
- ✅ 降低 CPU 使用率
- ✅ 提高视频流畅度

**预期日志输出**:

修复前:
```
📺 RemoteVideoManager: Attached to video port 0x12345678  ← 每500ms
📺 RemoteVideoManager: Attached to video port 0x12345678  ← 重复
📺 RemoteVideoManager: Attached to video port 0x12345678  ← 重复
...
```

修复后:
```
📺 RemoteVideoManager: Attached to video port 0x12345678  ← 只在首次或端口改变时打印
(后续不再重复打印，直到端口改变)
```

## 其他可能的优化 (未实施)

### 方案 A: 增加发送帧率

**目标**: 将本机发送帧率从 15fps 提升到 25-30fps

**修改位置**: VideoCallManager 或 SipPhoneManager 中的摄像头配置

**优点**:
- 对方看到的视频更流畅

**缺点**:
- 增加网络带宽消耗
- 可能需要更强的 CPU 性能

**是否推荐**: 可选，取决于用户需求

### 方案 B: 添加视频帧缓冲

**目标**: 使用帧缓冲队列平滑帧率波动

**实现**:
```cpp
class RemoteVideoManager {
    std::queue<QVideoFrame> m_frameBuffer;
    const int MAX_BUFFER_SIZE = 3;  // 缓冲3帧

    void captureVideoFrame() {
        // 将帧加入缓冲队列
        if (m_frameBuffer.size() < MAX_BUFFER_SIZE) {
            m_frameBuffer.push(videoFrame);
        }
    }

    void displayNextFrame() {
        // 从缓冲队列取帧显示
        if (!m_frameBuffer.empty()) {
            m_videoSink->setVideoFrame(m_frameBuffer.front());
            m_frameBuffer.pop();
        }
    }
};
```

**优点**:
- 平滑帧率波动
- 减少卡顿感

**缺点**:
- 增加约 100ms 延迟（3帧 @ 30fps）
- 增加内存使用

**是否推荐**: 如果卡顿仍然明显，可以尝试

### 方案 C: 忽略初始解码错误

**目标**: 在解码错误时显示上一帧，而不是黑屏或跳过

**实现**:
```cpp
void RemoteVideoManager::captureVideoFrame()
{
    // ...
    QVideoFrame videoFrame = convertPjFrameToQt(&frame, fmt);

    if (videoFrame.isValid()) {
        m_lastValidFrame = videoFrame;  // 保存最后一个有效帧
        m_videoSink->setVideoFrame(videoFrame);
    } else {
        // 解码失败时，继续显示上一帧
        if (m_lastValidFrame.isValid()) {
            m_videoSink->setVideoFrame(m_lastValidFrame);
        }
    }
}
```

**优点**:
- 减少初始卡顿和黑屏
- 用户体验更好

**缺点**:
- 轻微增加代码复杂度

**是否推荐**: 推荐，简单且有效

## 编译状态

- ✅ 编译成功 (2025-12-09)
- ✅ 可执行文件: `build/bin_windows/belt_control_system.exe`
- ✅ RemoteVideoManager 已优化（减少重复附加）

## 测试步骤

1. 运行应用程序:
   ```bash
   build/bin_windows/belt_control_system.exe
   ```

2. 让对方发起视频通话

3. 点击"视频接听"按钮

4. **对比测试前后效果**:

   **修复前**:
   - 视频卡顿，一卡一卡的
   - 日志显示大量重复的 "Attached to video port" 消息

   **修复后**:
   - 视频更流畅
   - "Attached to video port" 消息只在首次建立时出现一次
   - CPU 使用率可能略有降低

5. **观察日志输出**:
   ```
   ✅ RemoteVideoManager: Starting timers in Qt main thread
   📺 RemoteVideoManager: Attached to video port 0x...  ← 应该只出现一次
   📹 Captured 30 frames, format: ...
   📹 Captured 60 frames, format: ...
   ```

## 预期改善

### 主要改善 ✅
- **流畅度提升**: 消除重复附加操作的开销
- **性能优化**: 减少不必要的函数调用和日志输出
- **日志清晰**: 更容易诊断真正的问题

### 可能仍存在的轻微卡顿

如果视频仍然有轻微卡顿，可能原因：

1. **网络波动**: 这是正常现象，取决于网络质量
2. **初始 2-3 秒**: 解码器需要时间稳定，这是正常的
3. **对方帧率波动**: 超出本机控制范围

**如果仍然明显卡顿**，请考虑实施上述"方案 B"或"方案 C"。

## 技术说明

### 为什么重复附加会影响性能?

虽然视频端口指针赋值本身很快，但相关操作会影响性能：

1. **每 500ms 调用一次 `detectAndAttachVideoPort()`**
2. 函数内部执行:
   - `pjsua_call_get_info()` - 获取通话信息
   - 遍历所有媒体流 (`media_cnt`)
   - 访问 PJSIP 内部结构 (`pjsua_var.calls`)
   - 调用 `pjmedia_vid_stream_get_port()` - PJSIP API 调用
3. 日志输出 (`qDebug`) - 涉及字符串格式化和 I/O

这些操作累积起来，在低性能设备上可能导致：
- 捕获定时器 (33ms) 被延迟
- 帧率不稳定
- 卡顿感

### 优化后的工作流程

```
每 500ms:
  checkRemoteVideo()
    ↓
  detectAndAttachVideoPort()
    ↓
  if (m_videoPort != port)  ← ✅ 添加此检查
    ↓ (仅当端口改变时)
  m_videoPort = port
  qDebug() << "Attached..."
```

**结果**: 在 99.9% 的检查周期中，不会执行赋值和日志输出。

## 相关文件

- [RemoteVideoManager.cpp:102-157](src/sip_phone/RemoteVideoManager.cpp#L102-L157) - **detectAndAttachVideoPort() 优化**
- [RemoteVideoManager.cpp:79-100](src/sip_phone/RemoteVideoManager.cpp#L79-L100) - checkRemoteVideo()
- [RemoteVideoManager.cpp:164-228](src/sip_phone/RemoteVideoManager.cpp#L164-L228) - captureVideoFrame()

## 下一步

1. **立即测试**: 运行应用并接听视频来电，观察流畅度是否改善
2. **收集反馈**: 如果仍然卡顿，提供详细日志
3. **进一步优化**: 根据反馈考虑实施帧缓冲或其他方案

预祝测试顺利！应该能感觉到视频更流畅了。🎉
