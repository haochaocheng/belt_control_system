# 视频通话功能当前状态

## 最新修改 (2025-12-05)

### 问题描述

用户报告即使点击"语音通话"按钮,SIP INVITE消息中也包含视频流(m=video),导致FreeSWITCH服务器返回"488 Not Acceptable Here"错误。

### 已完成的修改

1. **PJSIP配置修改** ([config_site.h:57](file:///F:/0/pjproject-2.15.1/pjproject-2.15.1/pjlib/include/pj/config_site.h#L57))
   ```c
   /* CRITICAL: Disable video by default in new calls (audio-only default) */
   #define PJSUA_DEFAULT_VID_CNT           0    // 0 = no video by default
   ```

2. **PJSIP库已重新编译**
   - config_site.h修改时间: 2025-12-05 10:54:48
   - libpjsua库编译时间: 2025-12-05 10:57:31 (3分钟后)
   - 确认新配置已编译到库中

3. **应用程序代码**
   - [risipendpoint.cpp:201-208](file:///E:/2025/3_gongkongji/belt_control_system/src/risip/core/risipendpoint.cpp#L201-L208) 已清理,移除了不存在的`maxVideoCount`字段
   - 保持原有endpoint配置(线程数、时钟频率等)
   - 视频默认设置完全由PJSUA_DEFAULT_VID_CNT控制

4. **双按钮UI** ([SipDialPage.qml:328-448](file:///E:/2025/3_gongkongji/belt_control_system/src/qml/components/sip_phone/pages/SipDialPage.qml#L328-L448))
   - 语音通话按钮(绿色): 调用`SipPhoneManager.makeCall(number)`
   - 视频通话按钮(蓝色): 调用`SipPhoneManager.makeVideoCall(number)`

5. **应用程序已成功编译**
   - 编译时间: 刚刚完成
   - 状态: 100% Built target belt_control_system
   - 可执行文件: build/bin_windows/belt_control_system.exe

## 预期行为

### 语音通话 (PJSUA_DEFAULT_VID_CNT=0生效)

当点击"语音通话"按钮时:

1. 调用`SipPhoneManager.makeCall(number, false)`
2. Risip使用`CallOpParam(true)` - 使用默认呼叫设置
3. 由于`PJSUA_DEFAULT_VID_CNT=0`,默认呼叫设置中`vid_cnt=0`
4. SIP INVITE的SDP应该**只包含**:
   ```sdp
   m=audio 4000 RTP/AVP 96 97 98
   a=rtpmap:96 PCMU/8000
   a=rtpmap:97 PCMA/8000
   ```
5. **不应该包含**`m=video`行
6. FreeSWITCH应该返回`200 OK`,不再是`488 Not Acceptable Here`

### 视频通话 (re-INVITE方式)

当点击"视频通话"按钮时:

1. 调用`SipPhoneManager.makeVideoCall(number)` → `makeCall(number, true)`
2. 初始INVITE仍然是纯音频(因为PJSUA_DEFAULT_VID_CNT=0)
3. 对方接听,通话进入`CallConfirmed`状态
4. 自动调用`VideoCallManager.startVideoCall(callId)`
5. 发送re-INVITE添加视频流:
   ```sdp
   m=audio 4000 RTP/AVP 96 97 98
   m=video 4002 RTP/AVP 96      ← 通过re-INVITE添加
   a=rtpmap:96 H264/90000
   ```
6. 建立音视频通话

## 待测试验证

### 测试1: 验证语音通话SDP

**目的**: 确认`PJSUA_DEFAULT_VID_CNT=0`生效,纯音频通话不包含视频

**步骤**:
1. 启动应用程序
2. 登录SIP账户
3. 输入对方号码
4. 点击"语音通话"按钮(绿色,📞)
5. 抓取SIP INVITE消息

**预期结果**:
- SDP中**只有**`m=audio`行
- SDP中**没有**`m=video`行
- FreeSWITCH返回`200 OK`
- 通话成功建立

**如果失败**:
- 查看SDP内容,如果仍包含`m=video`,说明还有其他地方启用了视频
- 需要进一步排查Risip账户配置或PJSIP全局设置

### 测试2: 验证视频通话re-INVITE

**目的**: 确认re-INVITE方式可以正确添加视频流

**步骤**:
1. 输入对方号码
2. 点击"视频通话"按钮(蓝色,📹)
3. 观察日志输出

**预期日志**:
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

**预期结果**:
- 初始INVITE为纯音频
- 接听后自动发送re-INVITE添加视频
- 最终SDP包含音频和视频流
- 视频流建立(使用colorbar虚拟设备)

## 可能的问题和解决方案

### 问题1: 语音通话仍包含视频

**原因分析**:
- PJSUA_DEFAULT_VID_CNT=0可能没有生效
- Risip可能在账户级别启用了视频
- 应用程序复制的PJSIP库可能是旧版本

**解决方案**:
1. 确认应用程序使用的PJSIP库文件时间戳正确
   ```bash
   ls -lh e:/2025/3_gongkongji/belt_control_system/libs/pjsip/libpjsua*.a
   ```
2. 如果时间戳不对,重新复制:
   ```bash
   cp /f/0/pjproject-2.15.1/pjproject-2.15.1/pjsip/lib/*.a \
      e:/2025/3_gongkongji/belt_control_system/libs/pjsip/
   ```
3. 重新编译应用程序

### 问题2: re-INVITE添加视频失败

**原因分析**:
- VideoCallManager未正确初始化
- 视频设备(colorbar)不可用
- PJSUA C API调用失败

**解决方案**:
1. 检查VideoCallManager初始化日志
2. 确认PJMEDIA_VIDEO_DEV_HAS_CBAR_SRC=1在config_site.h中
3. 检查`pjsua_call_set_vid_strm()`返回状态

## 技术说明

### PJSUA_DEFAULT_VID_CNT的作用

此宏定义控制`pjsua_call_setting`结构的默认`vid_cnt`值:

```c
// 在 pjsua_call_setting_default() 中
cfg.vid_cnt = PJSUA_DEFAULT_VID_CNT;  // 从config_site.h读取
```

- `PJSUA_DEFAULT_VID_CNT=0`: 新通话默认无视频流
- `PJSUA_DEFAULT_VID_CNT=1`: 新通话默认包含视频流

### Risip如何创建通话

[risipcall.cpp:364-390](file:///E:/2025/3_gongkongji/belt_control_system/src/risip/core/risipcall.cpp#L364-L390):

```cpp
CallOpParam prm(true);  // true = useDefaultCallSetting
m_data->pjsipCall->makeCall(uri.toStdString(), prm);
```

`CallOpParam(true)`使用默认呼叫设置,其中`vid_cnt`由`PJSUA_DEFAULT_VID_CNT`决定。

### 为什么不在endpoint级别配置?

PJSUA2 C++ API的`MediaConfig`结构**不提供**`maxVideoCount`或类似字段。视频配置在以下级别:

1. **编译时**: `PJMEDIA_HAS_VIDEO` (启用/禁用视频编译支持)
2. **默认设置**: `PJSUA_DEFAULT_VID_CNT` (默认呼叫是否包含视频)
3. **呼叫级别**: `pjsua_call_setting.vid_cnt` (每个呼叫的视频流数量)

我们选择在级别2配置(默认设置),因为:
- 简单有效,一处修改全局生效
- 不需要修改Risip SDK代码
- 保持视频编译支持,但默认禁用
- 可以通过re-INVITE在需要时启用视频

## 下一步行动

1. **测试语音通话**: 确认SDP不包含视频,488错误已解决
2. **如果测试通过**: 用户可以正常使用语音通话功能
3. **测试视频通话**: 验证re-INVITE方式可以添加视频流
4. **如果测试失败**: 提供SIP日志,进一步诊断

## 文件修改清单

| 文件 | 状态 | 说明 |
|------|------|------|
| config_site.h | ✅ 已修改 | 添加PJSUA_DEFAULT_VID_CNT=0 (第57行) |
| PJSIP库 | ✅ 已重新编译 | 2025-12-05 10:57:31 |
| risipendpoint.cpp | ✅ 已修改 | 移除错误的maxVideoCount代码 (第201-208行) |
| 应用程序 | ✅ 已编译 | belt_control_system.exe |
| SipDialPage.qml | ✅ 已实现 | 双按钮UI (第328-448行) |
| SipPhoneManager.cpp | ✅ 已实现 | 视频通话逻辑 (第825-911行) |

---

**创建时间**: 2025-12-05
**最后更新**: 编译完成后
**状态**: ⏳ 待测试验证
**关键变更**: PJSUA_DEFAULT_VID_CNT=0 (在PJSIP级别禁用默认视频)
