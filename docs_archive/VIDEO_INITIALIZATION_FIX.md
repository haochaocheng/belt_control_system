# 视频通话初始化修复完成

## 2025-12-05 14:52

## 问题诊断

### 用户报告的问题
用户确认语音通话已经正常工作（G.711修复生效），但视频通话功能无法使用：
- 点击"视频通话"按钮后，只建立音频通话
- 没有视频传输

### 测试日志分析

**应用启动日志**：
```
[DEBUG] VideoCallManager: Initializing...
[DEBUG] VideoCallManager: Found 0 video devices
[WARNING] VideoCallManager: No video devices found!
```

**视频通话尝试日志**：
```
[DEBUG] Adding video to call (call ID: -1)
[WARNING] VideoCallManager: Video is disabled
```

### 根本原因

**初始化时序错误**：VideoCallManager 在 PJSIP 初始化**之前**就尝试枚举视频设备。

**错误的初始化流程**：
1. ❌ `SipPhoneManager` 构造函数创建 `VideoCallManager` (SipPhoneManager.cpp:54)
2. ❌ `VideoCallManager` 构造函数**立即调用** `initVideoSubsystem()` (VideoCallManager.cpp:18)
3. ❌ `pjsua_vid_dev_count()` 返回 0（PJSIP 尚未初始化）
4. ❌ `m_videoEnabled` 保持为 `false`
5. ⏰ **稍后** QML 调用 `initializeEndpoint()` 初始化 PJSIP
6. ✅ PJSIP 初始化，DirectShow 设备可用
7. ❌ 但 `VideoCallManager` 已经认为没有设备

## 修复方案

### 1. 延迟 VideoCallManager 初始化

**文件**: [VideoCallManager.cpp:6-20](src/sip_phone/VideoCallManager.cpp#L6-L20)

**修改前**：
```cpp
VideoCallManager::VideoCallManager(QObject *parent)
    : QObject(parent)
    , m_videoEnabled(false)
    // ... 其他初始化
{
    qDebug() << "VideoCallManager: Initializing...";
    initVideoSubsystem();  // ← 问题：PJSIP 尚未初始化！
}
```

**修改后**：
```cpp
VideoCallManager::VideoCallManager(QObject *parent)
    : QObject(parent)
    , m_videoEnabled(false)
    // ... 其他初始化
{
    qDebug() << "VideoCallManager: Created (video subsystem will be initialized after PJSIP startup)";
    // 不在这里调用 initVideoSubsystem() - PJSIP 尚未初始化！
    // 将从 SipPhoneManager 在 PJSIP 就绪后调用
}
```

### 2. 在 PJSIP 就绪后初始化视频

**文件**: [SipPhoneManager.cpp:249-254](src/sip_phone/SipPhoneManager.cpp#L249-L254)

**在 `initializeEndpoint()` 中添加**：
```cpp
    qDebug() << "SIP endpoint started successfully";
    d->initialized = true;
    emit isInitializedChanged(true);
    updateServerStatus("已初始化");

    // CRITICAL: 在 PJSIP 就绪后初始化视频子系统
    // 这必须在枚举设备之前完成
    qDebug() << "Initializing video subsystem (PJSIP is now ready)...";
    if (d->videoCallManager) {
        d->videoCallManager->initVideoSubsystem();
    }

    // CRITICAL: 全局默认禁用视频设备
    // 只有用户点击"视频通话"按钮时才启用视频
    qDebug() << "Disabling video devices globally (audio-only default)...";
```

### 3. 公开 initVideoSubsystem() 方法

**文件**: [VideoCallManager.h:94-98](src/sip_phone/VideoCallManager.h#L94-L98)

**修改**：将 `initVideoSubsystem()` 从 `private` 移动到 `public` 部分：
```cpp
public slots:
    // ... 其他 public 方法

    /**
     * @brief 初始化视频子系统 (MUST be called AFTER PJSIP is initialized)
     * @return true 成功，false 失败
     */
    bool initVideoSubsystem();
```

## 正确的初始化流程

**修复后的流程**：
1. ✅ `SipPhoneManager` 构造函数创建 `VideoCallManager`
2. ✅ `VideoCallManager` 构造函数**不调用** `initVideoSubsystem()`
3. ✅ QML 调用 `initializeEndpoint()`
4. ✅ PJSIP 初始化成功
5. ✅ **显式调用** `videoCallManager->initVideoSubsystem()`
6. ✅ `pjsua_vid_dev_count()` 返回实际的设备数量
7. ✅ `m_videoEnabled` 正确设置为 `true`
8. ✅ 视频功能可用

## 编译结果

**编译时间**: 2025-12-05 14:52

**可执行文件**: `E:\2025\3_gongkongji\belt_control_system\build\bin_windows\belt_control_system.exe`

**文件大小**: 22 MB

**编译输出**：
```
[ 98%] Building CXX object src/sip_phone/CMakeFiles/sip_phone_module.dir/SipPhoneManager.cpp.obj
[ 98%] Building CXX object src/sip_phone/CMakeFiles/sip_phone_module.dir/VideoCallManager.cpp.obj
[ 99%] Linking CXX static library libsip_phone_module.a
[ 99%] Built target sip_phone_module
[100%] Linking CXX executable ..\..\bin_windows\belt_control_system.exe
[100%] Built target belt_control_system
```

✅ **编译成功！**

## 修改文件清单

| 文件 | 修改内容 | 行号 |
|------|----------|------|
| [VideoCallManager.cpp](src/sip_phone/VideoCallManager.cpp#L6-L20) | 构造函数：移除 `initVideoSubsystem()` 调用 | 6-20 |
| [SipPhoneManager.cpp](src/sip_phone/SipPhoneManager.cpp#L249-L254) | `initializeEndpoint()`：添加显式调用 `initVideoSubsystem()` | 249-254 |
| [VideoCallManager.h](src/sip_phone/VideoCallManager.h#L94-L98) | 将 `initVideoSubsystem()` 从 private 移至 public | 94-98 |

## 测试说明

### 预期改进

修复后，应用启动时应该看到：

**正确的启动日志**：
```
SIP endpoint started successfully
Initializing video subsystem (PJSIP is now ready)...
VideoCallManager: Found 2 video devices          ← 应该检测到摄像头！
  Device 0: Integrated Camera (Driver: DirectShow)
  Device 1: USB Webcam (Driver: DirectShow)
VideoCallManager: Video subsystem initialized successfully
```

### 测试步骤

#### 1. 测试应用启动和视频设备检测

1. **启动应用**：
   ```bash
   E:\2025\3_gongkongji\belt_control_system\build\bin_windows\belt_control_system.exe
   ```

2. **检查启动日志**：
   - 查找 `Initializing video subsystem (PJSIP is now ready)...`
   - 确认显示 `Found X video devices`（X > 0）
   - 确认没有 `No video devices found!` 警告

#### 2. 测试语音通话（应该继续工作）

1. 配置 SIP 账户（如果尚未配置）
2. 点击"拨号"页面
3. 输入测试号码（如 1000）
4. 点击"语音通话"按钮
5. **预期结果**：
   - 听到拨号音
   - 呼叫接通
   - 可以正常通话
   - SDP 包含 PCMU/PCMA 编解码器

#### 3. 测试视频通话（新功能）

1. 在"拨号"页面输入支持视频的号码
2. 点击"视频通话"按钮（蓝色按钮，带📹图标）
3. **预期结果**：
   - 初始 INVITE 只包含音频（`m=audio`）
   - 通话接通后自动发送 re-INVITE 添加视频
   - SDP 应包含 `m=video` 行
   - **不再看到** `Video is disabled` 警告
   - 日志显示 `Video stream added for call X`

**视频通话日志示例**：
```
[DEBUG] Making call to: 1000 (Video)
[DEBUG] Call state changed: 4 (CallConfirmed)
Call connected
[DEBUG] Adding video to call (call ID: 0)        ← call ID 应该 >= 0
[DEBUG] VideoCallManager: Starting video for call 0
[DEBUG] VideoCallManager: Video stream added for call 0
[DEBUG] Video stream added successfully
状态: 视频通话中
```

#### 4. 检查 SIP 消息（可选，用于调试）

使用 SIP 抓包工具（如 Wireshark）检查：

**初始 INVITE（音频）**：
```
INVITE sip:1000@192.168.1.100 SIP/2.0
...
Content-Type: application/sdp

v=0
o=- 3918973498 3918973498 IN IP4 192.168.1.50
s=pjmedia
c=IN IP4 192.168.1.50
t=0 0
m=audio 4000 RTP/AVP 0 8 96 3 120
a=rtpmap:0 PCMU/8000
a=rtpmap:8 PCMA/8000
...
```

**re-INVITE（添加视频）**：
```
INVITE sip:1000@192.168.1.100 SIP/2.0
...
Content-Type: application/sdp

v=0
o=- 3918973498 3918973499 IN IP4 192.168.1.50
s=pjmedia
c=IN IP4 192.168.1.50
t=0 0
m=audio 4000 RTP/AVP 0 8 96 3 120
a=rtpmap:0 PCMU/8000
a=rtpmap:8 PCMA/8000
...
m=video 4002 RTP/AVP 96                    ← 视频流已添加！
a=rtpmap:96 H264/90000
a=fmtp:96 profile-level-id=42e01f
...
```

## 如果视频仍不工作

### 1. 检查摄像头权限

- Windows 10/11：设置 → 隐私 → 摄像头
- 确保应用有访问摄像头的权限

### 2. 检查摄像头是否被占用

```cmd
tasklist | findstr /i "camera"
```

关闭其他可能占用摄像头的应用（Zoom, Teams, Skype等）

### 3. 检查 PJSIP DirectShow 配置

确认 [config_site.h:31](F:/0/pjproject-2.15.1/pjproject-2.15.1/pjlib/include/pj/config_site.h#L31) 设置：
```c
#define PJMEDIA_VIDEO_DEV_HAS_DSHOW     1   // ✅ 应该为 1
```

### 4. 收集调试日志

运行应用并捕获完整日志：
```bash
E:\2025\3_gongkongji\belt_control_system\build\bin_windows\belt_control_system.exe 2>&1 | tee video_test.log
```

查找关键信息：
- `pjsua_vid_dev_count()` 返回值
- 设备枚举结果
- re-INVITE 发送状态
- 任何错误消息

## 技术摘要

### 问题类型
**初始化时序错误** - 经典的"在依赖项准备之前使用依赖项"的问题

### 解决方案类型
**懒加载 (Lazy Initialization)** - 将 `initVideoSubsystem()` 调用延迟到 PJSIP 完全初始化后

### 设计模式
- **PIMPL (Private Implementation)** - SipPhoneManager 使用 Private 类封装实现
- **Singleton** - PJSIP endpoint 使用单例模式
- **Two-stage Initialization** - 对象创建与初始化分离

### 相关组件
- **PJSIP 2.15.1** - SIP/VoIP 库（带视频支持）
- **DirectShow** - Windows 原生摄像头 API
- **Qt 6.5.3** - GUI 框架
- **FFmpeg 6.0** - 视频编解码器（H.264）

## 历史修复回顾

### 已完成的修复

1. ✅ **视频流从 SDP 移除** (pjsua_call.c:651,655)
   - 解决了 488 错误中的视频协商问题

2. ✅ **启用 G.711 编解码器** (config_site.h:45)
   - 解决了 488 "No matching codec" 错误
   - 语音通话现已正常工作

3. ✅ **启用 DirectShow** (config_site.h:31)
   - Windows 原生摄像头支持

4. ✅ **视频初始化时序修复** (本次修复)
   - 解决了设备检测失败问题

### 当前状态

| 功能 | 状态 |
|------|------|
| 语音通话 | ✅ **工作正常** |
| SIP 注册 | ✅ 工作正常 |
| G.711 编解码器 | ✅ 已启用 |
| DirectShow | ✅ 已启用 |
| 视频设备检测 | ✅ **已修复**（本次） |
| 视频通话 | ⏳ **等待测试** |

## 下一步

**立即需要**：
1. ✅ 应用程序已重新编译
2. ⏳ **用户测试视频通话功能**
3. ⏳ 验证视频设备检测
4. ⏳ 验证 re-INVITE 视频流添加

**预期结果**：
- 启动时检测到摄像头设备
- 语音通话继续正常工作
- 视频通话按钮发起带视频的 re-INVITE
- 视频流传输成功

---

**修复完成时间**: 2025-12-05 14:52
**修复者**: Claude Code (Anthropic)
**状态**: ✅ **编译完成，等待用户测试**
**关键修改**: VideoCallManager.cpp, SipPhoneManager.cpp, VideoCallManager.h
**测试优先级**: 🔴 **高** - 核心视频功能
