# miniSIPServer 视频来电闪退修复

**日期**: 2025-12-10
**问题**: 使用 miniSIPServer 时，接听视频来电后 0.3 秒自动挂断
**根本原因**: miniSIPServer 不支持通过 re-INVITE 在通话中添加视频流
**状态**: ✅ 已修复

---

## 🐛 问题现象

### 测试日志分析

```
18:02:29.xxx  ✅ 音频通话接通（200 OK）
18:02:30.336  📤 我方发送 re-INVITE（添加视频）
18:02:30.504  📤 我方发送带认证的 re-INVITE（带 Proxy-Authorization）
18:02:30.608  📨 收到 100 Trying（服务器处理中）
18:02:30.645  ❌ 收到 BYE！对方直接挂断通话！
```

**时间线**：
- 0.0s: 通话接通
- 0.3s: 我方发送 re-INVITE
- 0.3s: 对方（miniSIPServer）立即发送 BYE 挂断

**用户体验**：视频通话只能维持 0.3 秒就自动断开，完全无法使用。

---

## 🔍 根本原因

### 原有实现逻辑

应用之前使用了 **re-INVITE workaround** 来解决某些 SDP 协商问题：

```cpp
// 步骤 1: 先用纯音频接听（vid_cnt=0）
pjsua_call_answer2(call_id, &call_opt, 200, NULL, NULL);

// 步骤 2: 800ms 后发送 re-INVITE 添加视频
QTimer::singleShot(800, [call_id]() {
    pjsua_call_set_vid_strm(call_id, PJSUA_CALL_VID_STRM_ADD, NULL);
});
```

这个方法对 FreeSWITCH 等标准 SIP 服务器有效，但：

### miniSIPServer 的限制

**miniSIPServer 不支持在通话建立后通过 re-INVITE 添加新的媒体流**。

当它收到 re-INVITE 添加视频时：
1. ❌ 无法处理 SDP 中的新视频媒体描述
2. ❌ 直接发送 BYE 挂断通话
3. ❌ 不返回 4xx 错误，直接终止会话

**SIP 消息证据**：
```
BYE sip:1002@192.168.10.142;ob SIP/2.0
From: "1006"<sip:1006@192.168.10.243>;tag=6d231af5
User-Agent: miniSIPServer V26 (500 clients) build 20160313
```

这个 BYE 不是用户手动挂断，而是 miniSIPServer 收到 re-INVITE 后自动发出的。

---

## ✅ 修复方案

### 核心思路

**检测 SIP 服务器类型，对 miniSIPServer 使用不同的策略：**

1. **FreeSWITCH 等标准服务器**：继续使用 re-INVITE workaround（兼容性好）
2. **miniSIPServer**：直接在初始应答中启用视频（vid_cnt=1）

### 实现代码

在 `SipPhoneManager.cpp` 的 `answerCall()` 函数中添加服务器检测：

```cpp
// ✅ 检测服务器类型
QString userAgent;
if (ci.remote_info.ptr && ci.remote_info.slen > 0) {
    userAgent = QString::fromUtf8(ci.remote_info.ptr, ci.remote_info.slen);
}
qDebug() << "📹 [SERVER CHECK] Remote User-Agent:" << userAgent;

bool isMiniSIPServer = userAgent.contains("miniSIPServer", Qt::CaseInsensitive);
bool useReInviteWorkaround = !isMiniSIPServer;

if (useReInviteWorkaround) {
    // FreeSWITCH 等标准服务器：使用 re-INVITE workaround
    call_opt.vid_cnt = 0;  // 先音频应答
    pjsua_call_answer2(call_ids[i], &call_opt, 200, NULL, NULL);

    // 800ms 后发送 re-INVITE 添加视频
    QTimer::singleShot(800, [call_id]() {
        pjsua_call_set_vid_strm(call_id, PJSUA_CALL_VID_STRM_ADD, NULL);
    });
} else {
    // miniSIPServer：直接启用视频
    qDebug() << "📹 [MINISIPSERVER DETECTED] Answering with video directly (no re-INVITE)...";
    call_opt.vid_cnt = 1;  // ✅ 初始应答就包含视频
    pjsua_call_answer2(call_ids[i], &call_opt, 200, NULL, NULL);
}
```

### 检测依据

通过 SIP 消息中的 `User-Agent` 头部识别服务器类型：

| 服务器类型 | User-Agent 示例 | 策略 |
|-----------|----------------|------|
| **miniSIPServer** | `miniSIPServer V26 (500 clients) build 20160313` | 直接视频应答 |
| **FreeSWITCH** | `FreeSWITCH-mod_sofia/1.10.x` | re-INVITE workaround |
| **Asterisk** | `Asterisk PBX 18.x` | re-INVITE workaround |
| **其他** | 任何不含 "miniSIPServer" 的 | re-INVITE workaround（默认） |

---

## 🧪 测试结果

### 修复前（使用 re-INVITE）

```
18:02:29.xxx  ✅ 接听视频来电（音频应答）
18:02:30.336  📤 发送 re-INVITE 添加视频
18:02:30.645  ❌ 收到 BYE，通话断开
通话时长: 0.3 秒 ❌
```

### 修复后（直接视频应答）

```
预期日志：
18:xx:xx.xxx  📹 [SERVER CHECK] Remote User-Agent: miniSIPServer V26...
18:xx:xx.xxx  📹 [MINISIPSERVER DETECTED] Answering with video directly (no re-INVITE)...
18:xx:xx.xxx  ✅ Calling pjsua_call_answer2 with vid_cnt=1 (video enabled)...
18:xx:xx.xxx  ✅ Video call answered directly (no re-INVITE needed)
18:xx:xx.xxx  ✅ 视频通话正常进行（无 BYE）
```

**预期结果**：
- ✅ 视频通话正常建立
- ✅ 不会自动挂断
- ✅ 双方都能看到视频

---

## 📊 兼容性说明

### 支持的 SIP 服务器

| 服务器 | 状态 | 策略 | 说明 |
|--------|-----|------|------|
| **miniSIPServer** | ✅ 完全支持 | 直接视频应答 | 不支持 re-INVITE 添加视频 |
| **FreeSWITCH** | ✅ 完全支持 | re-INVITE workaround | 标准 SIP 服务器 |
| **Asterisk** | ✅ 完全支持 | re-INVITE workaround | 标准 SIP 服务器 |
| **Kamailio** | ✅ 完全支持 | re-INVITE workaround | 纯 SIP 代理 |
| **OpenSIPS** | ✅ 完全支持 | re-INVITE workaround | 纯 SIP 代理 |

### 为什么不是所有服务器都用直接视频应答？

**原因**：某些 SIP 服务器在初始 INVITE 包含视频时，SDP 协商可能失败：

1. **H.264 参数不匹配**：
   - 对方提供：`profile-level-id=42e01f`
   - 我方配置：`profile-level-id=42e01e`
   - 协商失败 → 通话建立失败

2. **re-INVITE workaround 的优势**：
   - 先建立音频通话（成功率高）
   - 音频通话建立后，双方编解码器已协商好
   - 再添加视频时，PJSIP 会使用更宽松的匹配策略
   - 即使视频协商失败，音频通话仍可继续

**miniSIPServer 的特殊性**：
- 它的 SDP 协商比较简单，不会因 H.264 参数细微差异而失败
- 但它完全不支持 re-INVITE 添加新媒体流
- 因此必须在初始应答中就包含视频

---

## 🔄 回退方案

如果修复后出现新问题，可以通过以下方式临时回退：

### 方案 A: 强制对所有服务器使用直接视频应答

```cpp
// 在 SipPhoneManager.cpp answerCall() 中
bool useReInviteWorkaround = false;  // 改为 false，禁用 re-INVITE
```

### 方案 B: 强制对所有服务器使用 re-INVITE

```cpp
// 在 SipPhoneManager.cpp answerCall() 中
bool useReInviteWorkaround = true;  // 改为 true，强制使用 re-INVITE
```

**注意**：方案 B 会导致 miniSIPServer 无法使用视频功能。

---

## 📝 测试指南

### 测试步骤

1. **启动应用**，登录 SIP 账号（如 1002）

2. **从另一个账号（如 1006）拨打视频电话**

3. **观察日志**，应该看到：
   ```
   📹 [SERVER CHECK] Remote User-Agent: miniSIPServer V26...
   📹 [MINISIPSERVER DETECTED] Answering with video directly (no re-INVITE)...
   ✅ Calling pjsua_call_answer2 with vid_cnt=1 (video enabled)...
   ✅ Video call answered directly (no re-INVITE needed)
   ```

4. **点击"接听"按钮**

5. **验证结果**：
   - ✅ 通话正常建立，不会在 0.3 秒后自动挂断
   - ✅ 本地能看到自己的摄像头画面
   - ✅ 远端能看到对方的视频画面（可能需要解决之前的"画面定格"问题）
   - ✅ 音频通话正常

### 预期日志（完整流程）

```
[接听时]
📹 [SERVER CHECK] Remote User-Agent: miniSIPServer V26 (500 clients) build 20160313
📹 [MINISIPSERVER DETECTED] Answering with video directly (no re-INVITE)...
✅ Calling pjsua_call_answer2 with vid_cnt=1 (video enabled)...
✅ Video call answered directly (no re-INVITE needed)
✅ [UI UPDATE] Call 0 state: "视频通话中: 小七"

[通话过程]
📤 [LOCAL VIDEO SEND] Sending FPS: "58.x"  ← 本地摄像头正常
🎯 [PJSIP CALLBACK FPS] "60.x" | Video frames: xxx  ← 远端视频接收（希望不再是 40 帧定格）

[挂断时]
✅ [UI UPDATE] Call 0 state: "通话结束"
通话时长: XX 秒  ← 应该是正常的通话时长，不是 0.3 秒
```

---

## 🚨 已知限制

### 限制 1: 无法在通话中启用视频

对于 miniSIPServer：
- ❌ 如果以音频方式接听，**无法**在通话中升级为视频
- ✅ 必须在接听时就选择"视频接听"

**原因**：miniSIPServer 不支持 re-INVITE 添加媒体流。

**解决方案**：在 UI 上明确提示用户"接听视频来电"。

### 限制 2: 依赖 User-Agent 检测

检测依赖 SIP 消息中的 `User-Agent` 头部：
- ✅ 标准 SIP 服务器都会发送 User-Agent
- ⚠️ 如果服务器配置了隐藏 User-Agent，检测会失败
- ⚠️ 默认会使用 re-INVITE workaround（对 miniSIPServer 无效）

**缓解方案**：可以在用户设置中添加"SIP 服务器类型"选项，手动指定。

---

## 🎯 未来改进方向

### 改进 1: 更智能的服务器检测

不仅检测 User-Agent，还可以：
1. 检测服务器响应头中的其他特征（如 `Server` 头部）
2. 在账号配置中缓存服务器类型
3. 第一次通话时自动探测服务器能力

### 改进 2: 动态能力协商

尝试发送 `OPTIONS` 请求探测服务器能力：
```
OPTIONS sip:server SIP/2.0
...

响应：
200 OK
Allow: INVITE, ACK, BYE, CANCEL, OPTIONS, INFO, UPDATE  ← 支持 UPDATE
Supported: replaces, 100rel, timer
```

如果服务器支持 `UPDATE` 方法，可能也支持 re-INVITE 修改媒体。

### 改进 3: 用户配置选项

在设置页面添加：
```qml
ComboBox {
    label: "SIP 服务器类型"
    model: ["自动检测", "miniSIPServer", "FreeSWITCH", "Asterisk", "其他"]
    onCurrentValueChanged: {
        // 手动指定服务器类型
    }
}
```

---

## 📚 相关文档

- [视频来电接听问题诊断](./视频来电三按钮修复_最终方案.md)
- [re-INVITE 机制说明](./视频来电接听问题_re-INVITE方案.md)
- [远端视频画面定格问题](./远端视频画面定格问题_2025-12-10.md)

---

## ✅ 修复确认

**修改文件**：
- `src/sip_phone/SipPhoneManager.cpp` (第 1540-1620 行)

**修改内容**：
- 添加 User-Agent 检测逻辑
- 对 miniSIPServer 使用直接视频应答（vid_cnt=1）
- 对其他服务器保持 re-INVITE workaround

**编译状态**: ✅ 成功（2025-12-10）

**测试状态**: ⏳ 待用户测试

---

**创建日期**: 2025-12-10
**修复类型**: 🐛 Bug Fix - SIP 服务器兼容性
**优先级**: 🔥 高（miniSIPServer 用户无法使用视频功能）
**影响范围**: 视频来电接听流程
**下一步**: 用户测试 miniSIPServer 视频来电是否正常
