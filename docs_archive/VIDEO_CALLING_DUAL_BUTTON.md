# 双按钮视频通话功能实现说明

## 功能概述

实现了 SIP 视频通话功能,用户可以通过两个独立的按钮选择:
- **语音通话** (纯音频通话)
- **视频通话** (音频+视频通话)

## 用户界面 (SipDialPage.qml)

### 拨号页面新增两个按钮

1. **语音通话按钮** (绿色, 📞 图标)
   - 文字: "语音通话"
   - 功能: 发起纯音频 SIP 通话
   - 调用: `SipPhoneManager.makeCall(number)`

2. **视频通话按钮** (蓝色, 📹 图标)
   - 文字: "视频通话"
   - 功能: 发起音频+视频 SIP 通话
   - 调用: `SipPhoneManager.makeVideoCall(number)`

## 实现架构

### 方案选择: re-INVITE 方式

由于 Risip SDK 不支持在初始 INVITE 中直接配置视频参数,采用以下方案:

1. **语音通话**: 直接使用 Risip SDK 创建纯音频通话
2. **视频通话**: 先建立音频通话,连接后通过 re-INVITE 添加视频流

### 核心代码逻辑 (SipPhoneManager.cpp)

```cpp
void SipPhoneManager::makeCall(const QString &number, bool enableVideo)
{
    // 1. 创建音频通话 (Risip callPhone)
    d->currentCall = callManager->callPhone(number);

    // 2. 捕获 enableVideo 标志到 lambda
    bool wantsVideo = enableVideo;

    // 3. 监听通话状态变化
    connect(d->currentCall, &risip::RisipCall::statusChanged, [this, wantsVideo]() {
        if (callState == risip::RisipCall::CallConfirmed) {
            // 通话接通

            // 如果这是视频通话,立即添加视频流
            if (wantsVideo && d->videoCallManager) {
                int callId = d->currentCall->callId();
                d->videoCallManager->startVideoCall(callId);  // re-INVITE with video
            }
        }
    });
}
```

### VideoCallManager 的作用

VideoCallManager 使用 PJSUA C API 直接操作视频流:

```cpp
bool VideoCallManager::startVideoCall(int callId)
{
    pjsua_call_vid_strm_op_param param;
    pjsua_call_vid_strm_op_param_default(&param);

    // 通过 re-INVITE 添加视频流
    status = pjsua_call_set_vid_strm(callId, PJSUA_CALL_VID_STRM_ADD, &param);

    return (status == PJ_SUCCESS);
}
```

## 视频设备配置

### PJSIP 配置 (config_site.h)

```c
/* 启用视频支持 */
#define PJMEDIA_HAS_VIDEO               1

/* FFmpeg 视频编解码器 (H.264) */
#define PJMEDIA_HAS_FFMPEG_VID_CODEC    1
#define PJMEDIA_HAS_FFMPEG_CODEC_H264   1

/* 使用 colorbar 虚拟设备 (避免 SDL 线程冲突) */
#define PJMEDIA_VIDEO_DEV_HAS_SDL       0
#define PJMEDIA_VIDEO_DEV_HAS_SDL2      0
#define PJMEDIA_VIDEO_DEV_HAS_CBAR_SRC  1   // 彩条测试视频源
#define PJMEDIA_VIDEO_DEV_HAS_NULL      1   // 空视频接收器
```

### 为什么禁用 SDL?

SDL2 会在 PJSIP 工作线程中创建窗口,与 Qt 主线程要求冲突,导致崩溃。
使用 colorbar 虚拟设备避免此问题,适用于测试和服务器端视频通话。

## 通话流程

### 语音通话流程

1. 用户点击 "语音通话" 按钮
2. QML 调用 `SipPhoneManager.makeCall(number)`
3. SipPhoneManager 创建纯音频 SIP 通话
4. SDP 只包含音频流 (m=audio)
5. 对方接听,建立语音通话

### 视频通话流程

1. 用户点击 "视频通话" 按钮
2. QML 调用 `SipPhoneManager.makeVideoCall(number)`
3. SipPhoneManager 先创建音频通话 (enableVideo=true)
4. 初始 INVITE 的 SDP 只包含音频流
5. 对方接听,通话状态变为 `CallConfirmed`
6. **自动触发**: 调用 `VideoCallManager.startVideoCall(callId)`
7. 发送 re-INVITE,SDP 中添加视频流 (m=video)
8. 对方接受,建立双向音视频流
9. 状态更新为 "视频通话中"

## SDP 示例

### 语音通话 SDP (纯音频)

```sdp
v=0
o=- 3927600883 3927600883 IN IP4 192.168.1.100
s=pjmedia
c=IN IP4 192.168.1.100
t=0 0
m=audio 4000 RTP/AVP 96 97 98
a=rtpmap:96 PCMU/8000
a=rtpmap:97 PCMA/8000
a=rtpmap:98 telephone-event/8000
```

### 视频通话 re-INVITE SDP (音频+视频)

```sdp
v=0
o=- 3927600883 3927600884 IN IP4 192.168.1.100
s=pjmedia
c=IN IP4 192.168.1.100
t=0 0
m=audio 4000 RTP/AVP 96 97 98
a=rtpmap:96 PCMU/8000
a=rtpmap:97 PCMA/8000
a=rtpmap:98 telephone-event/8000
m=video 4002 RTP/AVP 96
a=rtpmap:96 H264/90000
a=fmtp:96 profile-level-id=42e01f;packetization-mode=1
```

## 测试指南

### 测试环境

- SIP 服务器: FreeSWITCH (支持视频)
- 对端客户端: pjsip 客户端 (支持视频)

### 测试步骤

1. **测试语音通话**
   - 启动应用程序
   - 登录 SIP 账户
   - 输入对方号码
   - 点击 "语音通话" 按钮 (📞)
   - 验证: 只有音频,无视频

2. **测试视频通话**
   - 输入对方号码
   - 点击 "视频通话" 按钮 (📹)
   - 观察日志: 应看到 "Adding video to call" 和 "Video stream added successfully"
   - 验证: 音频正常,视频流已建立 (colorbar 或摄像头)

### 预期日志输出

#### 语音通话日志

```
[DEBUG] Making call to: 1234 (Audio only)
Call state changed: 6 (Early - ringing)
Call state changed: 4 (Confirmed)
Call connected
```

#### 视频通话日志

```
[DEBUG] Making call to: 1234 (Video)
Call state changed: 6 (Early - ringing)
Call state changed: 4 (Confirmed)
Call connected
[DEBUG] Adding video to call (call ID: 0)
VideoCallManager: Starting video for call 0
VideoCallManager: Video stream added for call 0
[DEBUG] Video stream added successfully
```

## 兼容性说明

### 服务器兼容性

- ✅ **FreeSWITCH**: 完全支持,可处理 re-INVITE
- ✅ **Asterisk**: 支持,需启用视频支持
- ⚠️ **其他 SIP 服务器**: 需要支持 re-INVITE 和视频编解码器 (H.264)

### 客户端兼容性

- ✅ **pjsip 客户端**: 完全兼容
- ✅ **Linphone**: 支持
- ✅ **Zoiper**: 支持
- ⚠️ **仅音频客户端**: 视频按钮应降级为语音通话 (服务器会拒绝视频)

## 已知限制

1. **无真实摄像头**: 当前使用 colorbar 虚拟设备进行测试
   - 要启用真实摄像头,需要修改 config_site.h 启用适当的视频设备驱动

2. **无视频显示窗口**: VideoCallManager 已准备就绪,但需要:
   - 创建 QML VideoRenderer 组件
   - 将 native window handle 传递给 PJSIP

3. **re-INVITE 延迟**: 视频在通话接通后添加,有短暂延迟
   - 可以通过修改 PJSIP 账户配置在初始 INVITE 中包含视频 (需要更深入的 Risip SDK 修改)

## 下一步改进

1. **启用真实摄像头支持**
   - 修改 config_site.h 启用 V4L2 (Linux) 或 DirectShow (Windows)
   - 重新编译 PJSIP 库

2. **实现视频显示窗口**
   - 创建 VideoCallWindow.qml
   - 嵌入 native 视频窗口
   - 实时显示本地和远程视频流

3. **优化初始 INVITE**
   - 研究 Risip SDK 账户配置 API
   - 在账户级别启用视频,使初始 INVITE 包含视频

4. **视频控制功能**
   - 切换摄像头
   - 禁用/启用视频流
   - 视频质量调整

## 文件修改清单

| 文件 | 修改内容 |
|------|----------|
| `SipPhoneManager.h` | 添加 `makeVideoCall()` 方法声明 |
| `SipPhoneManager.cpp` | 实现视频通话逻辑,集成 VideoCallManager |
| `SipDialPage.qml` | 替换单按钮为双按钮 (语音+视频) |
| `VideoCallManager.h` | 已存在 (无修改) |
| `VideoCallManager.cpp` | 已存在 (无修改) |
| `config_site.h` (PJSIP) | 启用视频支持,禁用 SDL,启用 colorbar |

## 技术亮点

1. **双按钮设计**: 用户友好,清晰区分语音和视频通话
2. **re-INVITE 方式**: 绕过 Risip SDK 限制,灵活添加视频
3. **Lambda 捕获**: 优雅地在回调中保持 `enableVideo` 状态
4. **VideoCallManager 复用**: 充分利用现有视频管理器,避免重复开发
5. **渐进式视频**: 先建立稳定音频,再升级到视频,提高成功率

---

**创建日期**: 2025-12-05
**作者**: Claude Code (Anthropic)
**版本**: 1.0
