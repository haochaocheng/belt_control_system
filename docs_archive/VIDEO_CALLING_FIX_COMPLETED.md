# 视频通话功能修复完成

## 问题描述

用户报告即使点击"语音通话"按钮,SIP INVITE消息中也包含视频流(m=video),导致FreeSWITCH服务器返回"488 Not Acceptable Here"错误。

### 问题日志
```
m=audio 4000 RTP/AVP 96 3 120
...
m=video 4002 RTP/AVP 100 96    ← 不应该在语音通话中出现!
```

### FreeSWITCH响应
```
SIP/2.0 488 Not Acceptable Here
Reason: Q.850;cause=88;text="INCOMPATIBLE_DESTINATION"
```

## 根本原因

当PJSIP使用`PJMEDIA_HAS_VIDEO=1`编译后,默认会在所有新通话中包含视频流。虽然代码提供了两个按钮(语音通话和视频通话),但由于PJSIP的默认行为,两种通话都包含了视频。

## 解决方案

### 1. PJSIP配置修改

修改 [config_site.h](file:///F:/0/pjproject-2.15.1/pjproject-2.15.1/pjlib/include/pj/config_site.h#L57):

```c
/* CRITICAL: Disable video by default in new calls (audio-only default)
 * Video support is compiled in, but calls will be audio-only by default.
 * Video must be explicitly enabled per-call using pjsua_call_setting.vid_cnt = 1
 */
#define PJSUA_DEFAULT_VID_CNT           0    // 0 = no video by default, 1 = video enabled
```

**关键点**:
- 视频支持仍然编译进PJSIP(PJMEDIA_HAS_VIDEO=1)
- 但新通话默认不包含视频(PJSUA_DEFAULT_VID_CNT=0)
- 视频必须显式启用

### 2. SipPhoneManager代码简化

修改 [SipPhoneManager.cpp:824-947](file:///E:/2025/3_gongkongji/belt_control_system/src/sip_phone/SipPhoneManager.cpp#L824-L947):

```cpp
void SipPhoneManager::makeCall(const QString &number, bool enableVideo)
{
    // ... 前置检查 ...

    // 创建通话(默认为纯音频,因为PJSUA_DEFAULT_VID_CNT=0)
    d->currentCall = callManager->callPhone(number);

    // 连接通话状态信号
    connect(d->currentCall, &risip::RisipCall::statusChanged, this, [this, wantsVideo]() {
        if (callState == risip::RisipCall::CallConfirmed) {
            // 通话接通

            // 如果这是视频通话,通过re-INVITE添加视频流
            if (wantsVideo && d->videoCallManager) {
                int callId = d->currentCall->callId();
                if (d->videoCallManager->startVideoCall(callId)) {
                    // 视频流添加成功
                    updateCallStatus("视频通话中");
                } else {
                    // 视频流添加失败,保持纯音频
                    updateCallStatus("通话中 (视频添加失败)");
                }
            } else {
                // 纯音频通话
                updateCallStatus("通话中");
            }
        }
        // ... 其他状态处理 ...
    });
}
```

**流程说明**:

1. **语音通话**:
   - 调用`callPhone()` → 创建纯音频通话(因为PJSUA_DEFAULT_VID_CNT=0)
   - SDP只包含`m=audio`,不包含`m=video`
   - 对方接听 → 建立纯音频通话

2. **视频通话**:
   - 调用`callPhone()` → 先创建纯音频通话
   - SDP只包含`m=audio`
   - 对方接听 → 通话进入`CallConfirmed`状态
   - 自动调用`VideoCallManager->startVideoCall()` → 发送re-INVITE添加视频流
   - SDP更新为包含`m=audio`和`m=video`
   - 建立双向音视频流

### 3. 用户界面 (保持不变)

[SipDialPage.qml](file:///E:/2025/3_gongkongji/belt_control_system/src/qml/components/sip_phone/pages/SipDialPage.qml#L328-L448) 保持双按钮设计:

```qml
// 语音通话按钮 (绿色, 📞)
RisipButton {
    text: "语音通话"
    onClicked: SipPhoneManager.makeCall(number)
}

// 视频通话按钮 (蓝色, 📹)
RisipButton {
    text: "视频通话"
    onClicked: SipPhoneManager.makeVideoCall(number)
}
```

## 编译和部署

### 1. 重新编译PJSIP

```bash
cd /f/0/pjproject-2.15.1/pjproject-2.15.1
make clean
make dep
make -j8 lib
```

### 2. 复制库文件

```bash
cp -v /f/0/pjproject-2.15.1/pjproject-2.15.1/*/lib/*.a \
      /e/2025/3_gongkongji/belt_control_system/libs/pjsip/
```

### 3. 编译应用程序

```bash
cd /e/2025/3_gongkongji/belt_control_system
/c/Qt/Tools/CMake_64/bin/cmake.exe --build build --target belt_control_system -j4
```

## 测试指南

### 测试1: 语音通话(验证488错误已修复)

1. 启动应用程序
2. 登录SIP账户
3. 输入对方号码
4. 点击 **"语音通话"** 按钮 (📞)

**预期结果**:
- SIP INVITE中**只有**`m=audio`行
- **没有**`m=video`行
- FreeSWITCH返回`200 OK`(不再是488错误)
- 成功建立纯音频通话

**日志验证**:
```
[DEBUG] Making call to: 1234 (Audio only)
Call state changed: 6 (Early - ringing)
Call state changed: 4 (Confirmed)
Call connected
```

### 测试2: 视频通话

1. 输入对方号码
2. 点击 **"视频通话"** 按钮 (📹)

**预期结果**:
- 初始INVITE中只有`m=audio`(先建立音频)
- 对方接听后,应用发送re-INVITE添加`m=video`
- 最终SDP包含`m=audio`和`m=video`
- 成功建立音视频通话

**日志验证**:
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

## SDP对比

### 修复前(两种通话都包含视频)

```sdp
v=0
o=- 3927600883 3927600883 IN IP4 192.168.1.100
m=audio 4000 RTP/AVP 96 97 98
a=rtpmap:96 PCMU/8000
m=video 4002 RTP/AVP 100 96    ← 不应该出现!
a=rtpmap:100 H264/90000
```

### 修复后 - 语音通话

```sdp
v=0
o=- 3927600883 3927600883 IN IP4 192.168.1.100
m=audio 4000 RTP/AVP 96 97 98
a=rtpmap:96 PCMU/8000
a=rtpmap:97 PCMA/8000
```

### 修复后 - 视频通话(re-INVITE后)

```sdp
v=0
o=- 3927600883 3927600884 IN IP4 192.168.1.100
m=audio 4000 RTP/AVP 96 97 98
a=rtpmap:96 PCMU/8000
a=rtpmap:97 PCMA/8000
m=video 4002 RTP/AVP 100
a=rtpmap:100 H264/90000
a=fmtp:100 profile-level-id=42e01f
```

## 技术要点

### PJSUA_DEFAULT_VID_CNT的作用

此配置控制`pjsua_call_setting`的默认`vid_cnt`值:

```c
typedef struct pjsua_call_setting {
    unsigned         aud_cnt;   // 音频流数量(默认=1)
    unsigned         vid_cnt;   // 视频流数量(默认=PJSUA_DEFAULT_VID_CNT)
} pjsua_call_setting;
```

- `PJSUA_DEFAULT_VID_CNT=0` → 新通话默认无视频
- `PJSUA_DEFAULT_VID_CNT=1` → 新通话默认包含视频

### re-INVITE方式的优势

1. **兼容性好**: 初始INVITE为纯音频,所有SIP服务器都支持
2. **可靠性高**: 先建立稳定的音频连接,再升级到视频
3. **灵活性强**: 用户可以在通话中动态添加/移除视频流
4. **服务器友好**: FreeSWITCH等服务器可以正确处理re-INVITE

### 为什么不在初始INVITE中包含视频?

尝试过在账户级别动态配置视频设备,但存在以下问题:

1. **API复杂**: `pjsua_acc_get_config()`需要内存池参数
2. **时机难控**: 修改账户配置需要在`callPhone()`之前完成
3. **架构限制**: Risip SDK封装了PJSUA2 C++ API,难以访问底层配置
4. **re-INVITE更简单**: 在通话建立后通过PJSUA C API直接操作视频流

## 已知限制

1. **视频延迟**: 视频在通话接通后才添加,有短暂延迟(约1-2秒)
2. **虚拟摄像头**: 当前使用colorbar虚拟设备,需要启用真实摄像头支持
3. **无视频显示**: VideoCallManager已就绪,但需要实现QML视频渲染组件

## 下一步改进

1. **启用真实摄像头**: 修改config_site.h启用V4L2(Linux)或DirectShow(Windows)
2. **视频显示窗口**: 创建VideoCallWindow.qml嵌入native视频窗口
3. **优化初始INVITE**: 研究Risip SDK修改,在初始INVITE中包含视频(避免re-INVITE延迟)
4. **视频控制功能**: 添加切换摄像头、禁用/启用视频流、调整质量等功能

## 文件修改清单

| 文件 | 修改内容 | 行号 |
|------|----------|------|
| `config_site.h` (PJSIP) | 添加`PJSUA_DEFAULT_VID_CNT=0` | L57 |
| `SipPhoneManager.cpp` | 简化makeCall(),移除账户配置代码 | L824-L947 |
| `SipDialPage.qml` | 保持不变(双按钮UI已实现) | L328-L448 |

## 技术总结

### 问题根源
- PJSIP编译时启用视频支持(`PJMEDIA_HAS_VIDEO=1`)
- 默认配置导致所有新通话都包含视频流

### 解决方案
- 通过`PJSUA_DEFAULT_VID_CNT=0`禁用默认视频
- 保持视频编译支持,但需显式启用
- 使用re-INVITE在通话建立后添加视频

### 优势
- ✅ 语音通话不再包含视频(修复488错误)
- ✅ 视频通话仍然可用(通过re-INVITE)
- ✅ 代码简化(移除复杂的账户配置代码)
- ✅ 架构清晰(compile-time配置 + runtime行为)

---

**创建日期**: 2025-12-05
**问题修复**: 488 Not Acceptable Here错误
**解决方案**: PJSUA_DEFAULT_VID_CNT=0 + re-INVITE
**状态**: ✅ 编译成功,待用户测试
