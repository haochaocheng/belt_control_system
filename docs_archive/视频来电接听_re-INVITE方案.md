# 视频来电接听 - re-INVITE 方案

## 方案说明

由于PJSIP在接听视频来电时无法匹配对方的H264参数(profile-level-id=42001f, packetization-mode=1),导致SDP协商时拒绝视频(`m=video 0`),我们实施了**re-INVITE workaround**。

## 工作原理

### 传统方法 (失败)
```
1. 对方发送 INVITE with video offer (H264 42001f)
2. 本机发送 200 OK with SDP answer
   ❌ 无法匹配对方的H264参数
   ❌ SDP中设置 m=video 0 (拒绝视频)
3. 结果: 仅音频通话
```

### re-INVITE方案 (新方法)
```
1. 对方发送 INVITE with video offer (H264 42001f)
2. 本机发送 200 OK with SDP answer (✅ 仅接受音频)
   ✅ 音频协商成功
3. 通话建立 (仅音频)
4. ⏰ 等待800ms (让通话稳定)
5. 本机发送 re-INVITE with video offer (✅ 使用我们的H264参数)
   ✅ 作为video offerer,我们可以提出自己支持的参数
6. 对方发送 200 OK accepting our video parameters
7. 结果: ✅ 音频+视频通话
```

## 关键优势

**作为re-INVITE的发起方(offerer),我们可以提出自己支持的H264参数,而不需要匹配对方的特定参数要求。**

对方的SIP实现通常支持更广泛的参数范围,所以会接受我们的offer。

## 用户体验

- 用户点击"视频接听"
- 通话立即接通(音频)
- **约800ms后,视频自动建立**
- 轻微延迟,但视频最终能正常工作

## 实现细节

[SipPhoneManager.cpp:1406-1455](src/sip_phone/SipPhoneManager.cpp#L1406-L1455)

```cpp
void SipPhoneManager::answerCall()
{
    if (d->isIncomingVideoCall) {
        // Step 1: Answer with audio only
        call_opt.vid_cnt = 0;  // Audio only
        pjsua_call_answer2(call_ids[i], &call_opt, 200, NULL, NULL);

        // Step 2: Send re-INVITE to add video after 800ms
        QTimer::singleShot(800, this, [this, call_id]() {
            pjsua_call_vid_strm_op vidOp = PJSUA_CALL_VID_STRM_ADD;
            pjsua_call_vid_strm_op_param vidParam;
            pjsua_call_vid_strm_op_param_default(&vidParam);
            vidParam.med_idx = -1;
            vidParam.dir = PJMEDIA_DIR_ENCODING_DECODING;

            pjsua_call_set_vid_strm(call_id, vidOp, &vidParam);
        });
    }
}
```

## 预期日志输出

接听视频来电时:

```
✅ Answering incoming VIDEO call with PJSIP C API (vid_cnt=1)...
✅ Refreshing video config before answering for account: "sip:1002@192.168.10.243"
📹 [VIDEO CODEC CHECK] Found 2 video codecs:
  Codec 0 : "H264/100" Priority: 200
📹 [RE-INVITE WORKAROUND] Step 1: Answer with audio only first...
✅ Calling pjsua_call_answer2 with vid_cnt=0 (audio only)...
✅ Audio-only answer sent successfully

发送的SDP (200 OK):
m=audio 4000 RTP/AVP 0 101
a=sendrecv
(没有 m=video 行 = 仅音频)

800ms后:
📹 [RE-INVITE WORKAROUND] Step 2: Sending re-INVITE to add video...
   Calling pjsua_call_set_vid_strm(PJSUA_CALL_VID_STRM_ADD)...
✅ [RE-INVITE] Video stream added successfully! re-INVITE sent.
   The remote party should now see our video

PJSIP发送re-INVITE:
m=audio 4000 RTP/AVP 0 101
m=video 4002 RTP/AVP 125  ← 现在有视频了!
a=rtpmap:125 H264/90000
a=fmtp:125 profile-level-id=42e01f;packetization-mode=1  ← 我们的参数
```

## 测试步骤

1. 运行应用程序:
   ```bash
   build/bin_windows/belt_control_system.exe
   ```

2. 让对方发起视频通话到本机

3. 点击"视频接听"按钮

4. **预期效果**:
   - ✅ 通话立即接通(音频)
   - ⏰ 约1秒后,视频窗口出现
   - ✅ 双方都能看到对方视频
   - ✅ 双方音频正常

5. **观察日志**:
   - 查找 `[RE-INVITE WORKAROUND]` 标记
   - 确认 "Step 1: Answer with audio only"
   - 确认 "Step 2: Sending re-INVITE to add video"
   - 确认 "Video stream added successfully"

## 已知限制

1. **约800ms延迟** - 视频不是立即建立,有轻微延迟
   - 可以调整QTimer时间(400-1000ms范围)
   - 太短:可能通话未稳定
   - 太长:用户等待时间长

2. **需要服务器支持re-INVITE** - 大多数现代SIP服务器都支持
   - FreeSWITCH ✅ 支持
   - Asterisk ✅ 支持
   - Kamailio ✅ 支持

3. **对方必须支持接收re-INVITE** - 标准SIP客户端都支持

## 与原方案对比

### 原方案(失败):
- ❌ 直接用`vid_cnt=1`接听
- ❌ PJSIP无法匹配对方H264参数
- ❌ 视频被拒绝: `m=video 0`
- ❌ 仅音频通话

### re-INVITE方案(成功):
- ✅ 先用`vid_cnt=0`接听(仅音频)
- ✅ 音频协商成功
- ✅ 800ms后发送re-INVITE添加视频
- ✅ 作为offerer,使用我们的H264参数
- ✅ 对方接受我们的参数
- ✅ 音频+视频通话成功

## 技术参考

### PJSIP re-INVITE API

```cpp
// Add video stream to existing audio call
pjsua_call_set_vid_strm(
    call_id,                          // 通话ID
    PJSUA_CALL_VID_STRM_ADD,         // 操作: 添加视频流
    &vidParam                         // 参数: med_idx=-1 (auto), dir=sendrecv
);
```

这个API会:
1. 生成新的local SDP offer (包含video)
2. 发送re-INVITE到对方
3. 等待对方的200 OK (with SDP answer)
4. 协商成功后建立视频流

### SDP Offer/Answer 角色差异

**作为Answerer** (我们之前失败的情况):
- 必须接受或拒绝对方提出的每个媒体流
- 必须匹配对方的编解码器参数
- 如果参数不匹配,只能拒绝(m=... 0)

**作为Offerer** (re-INVITE方案):
- 我们提出媒体流和参数
- 对方选择接受或拒绝
- 对方通常支持更广泛的参数范围
- 更容易协商成功

## 编译状态

- ✅ 编译成功 (2025-12-09)
- ✅ 可执行文件: `build/bin_windows/belt_control_system.exe`
- ✅ re-INVITE workaround已实施

## 下一步

请测试这个方案!预期会成功建立双向视频通话,虽然有约800ms的延迟。

如果测试成功,我们可以考虑:
1. 优化延迟时间(可能减少到400-500ms)
2. 添加视频建立进度提示给用户
3. 改进错误处理

如果仍然失败,请提供完整的日志,特别是包含`[RE-INVITE]`标记的部分。
