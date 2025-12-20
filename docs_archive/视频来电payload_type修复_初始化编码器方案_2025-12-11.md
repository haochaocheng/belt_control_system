# 视频来电 Payload Type 修复 - 初始化编码器方案

**日期**: 2025-12-11
**问题**: 接听 miniSIPServer 视频来电时，本机能接收对方视频，但对方（PortSIP UC Client）看不到本机视频
**根本原因**: RTP Payload Type 协商不匹配

---

## 问题分析

### 1. 之前的尝试

#### 方案 A: 直接用 vid_cnt=1 应答
```cpp
call_opt.vid_cnt = 1;
pjsua_call_answer2(call_id, &call_opt, 200, NULL, NULL);
```
**问题**: SDP answer 中视频端口为 0: `m=video 0 RTP/AVP 125`
**原因**: 视频编码器未初始化，PJSIP 无法分配 RTP 端口

#### 方案 B: 先 audio-only 应答，再发 re-INVITE 激活视频
```cpp
// Step 1: Answer with vid_cnt=0
call_opt.vid_cnt = 0;
pjsua_call_answer2(call_id, &call_opt, 200, NULL, NULL);

// Step 2: Send re-INVITE with CHANGE_DIR
pjsua_call_set_vid_strm(call_id, PJSUA_CALL_VID_STRM_CHANGE_DIR, &param);
```
**问题**: Payload type 不匹配
- 原始 INVITE: `m=video 20050 RTP/AVP 125` (远端提供)
- Audio-only 应答: `m=video 0 RTP/AVP 0` (拒绝视频)
- re-INVITE: `m=video 4002 RTP/AVP 100 96` (本机新 offer，使用默认 pt=100)
- 远端应答: `m=video 20050 RTP/AVP 125` (远端仍用 pt=125)

**结果**:
- ✅ 本机接收视频正常 (本机解码器适配 pt=125)
- ❌ 对方看不到本机视频 (对方期望 pt=125，但收到 pt=100)

### 2. 为什么会出现 Payload Type 不匹配？

在 SIP/SDP 协商中：
1. **Offer-Answer 模型**: Offer 方提出 payload types，Answer 方从中选择
2. **初始 INVITE**: 远端 offer `pt=125`，我们应该在 answer 中接受 `pt=125`
3. **Audio-only 应答**: 我们拒绝了视频，协商中断
4. **re-INVITE**: 我们发起新 offer，使用 PJSIP 默认的 `pt=100,96`
5. **协商失败**: 远端在 answer 中用 `pt=125`，但我们的 RTP 包用 `pt=100`

### 3. 真正的问题

方案 A 失败的根本原因：**视频编码器未初始化**

PJSIP 在应答时需要：
1. 初始化视频编码器
2. 分配 RTP 端口
3. 生成 SDP answer

如果编码器未就绪，PJSIP 会生成 `m=video 0` (拒绝)。

---

## 解决方案

### 核心思路

**在应答前初始化视频编码器，然后直接用 vid_cnt=1 应答**

这样可以：
1. ✅ 正确协商 payload type (接受远端的 pt=125)
2. ✅ 避免 re-INVITE (无需额外协商)
3. ✅ 编码器就绪，SDP 中视频端口正常

### 实现代码

**文件**: `src/sip_phone/SipPhoneManager.cpp` (行 1534-1614)

```cpp
// ✅ NEW APPROACH: Answer with video AFTER ensuring encoder is initialized
qDebug() << "📹 [VIDEO CALL] Initializing video encoder before answering...";

// ✅ Step 1: Pre-initialize video capture device
pjmedia_vid_dev_index cap_dev = d->videoCallManager->captureDevId();
pj_status_t preview_status = pjsua_vid_preview_start(cap_dev, NULL);
if (preview_status == PJ_SUCCESS) {
    qDebug() << "✅ Video preview started on device" << cap_dev;
    QThread::msleep(100);  // Give encoder 100ms to initialize
    pjsua_vid_preview_stop(cap_dev);
    qDebug() << "✅ Video preview stopped, encoder is initialized";
}

// ✅ Step 2: Answer with video enabled
call_opt.vid_cnt = 1;  // Enable video
status = pjsua_call_answer2(call_ids[i], &call_opt, 200, NULL, NULL);
```

### 关键步骤

1. **启动预览**：`pjsua_vid_preview_start(cap_dev, NULL)`
   - 初始化视频捕获设备
   - 启动编码器管道
   - 100ms 足够让编码器准备好

2. **停止预览**：`pjsua_vid_preview_stop(cap_dev)`
   - 停止预览窗口
   - 保留编码器状态（已初始化）
   - 编码器将用于通话

3. **应答视频呼叫**：`vid_cnt=1`
   - 编码器已就绪
   - PJSIP 正确分配 RTP 端口
   - SDP answer 接受远端的 `pt=125`

### 辅助修改

**文件**: `src/sip_phone/VideoCallManager.h` (行 105)

添加便捷访问方法：
```cpp
pjmedia_vid_dev_index captureDevId() const { return m_captureDevId; }
```

---

## 预期效果

### SDP 协商流程

```
1. 远端 INVITE offer:
   m=video 20050 RTP/AVP 125
   a=rtpmap:125 H264/90000
   a=fmtp:125 profile-level-id=42001f;packetization-mode=1

2. 本机 200 OK answer (vid_cnt=1):
   m=video 4002 RTP/AVP 125    ← 接受 pt=125
   a=rtpmap:125 H264/90000
   a=fmtp:125 profile-level-id=42e01e;packetization-mode=1

3. RTP 数据流:
   本机 → 远端: RTP packets with pt=125  ✅
   远端 → 本机: RTP packets with pt=125  ✅
```

### 测试检查点

1. **SDP answer 中视频端口不为 0**
   - ✅ 应该是: `m=video 4002 RTP/AVP 125`
   - ❌ 不应该是: `m=video 0 RTP/AVP 0`

2. **Payload type 一致**
   - SDP: `a=rtpmap:125 H264/90000`
   - 统计: `TX pt=125`

3. **呼叫不会立即挂断**
   - miniSIPServer 应返回 `200 OK`
   - 不应返回 `BYE`

4. **双方都能看到视频**
   - ✅ 本机看到对方视频
   - ✅ 对方（PortSIP UC Client）看到本机视频

---

## 测试步骤

1. **启动应用程序**
   ```bash
   cd e:\2025\3_gongkongji\belt_control_system
   .\build\bin_windows\belt_control_system.exe
   ```

2. **从 PortSIP UC Client 发起视频呼叫**
   - 确保 PortSIP 客户端已配置 miniSIPServer
   - 发起视频通话到本应用

3. **接听视频呼叫**
   - 点击"接听视频"按钮（三按钮界面）

4. **查看日志关键信息**
   ```
   📹 [VIDEO CALL] Initializing video encoder before answering...
   📹 Step 1: Pre-initializing video capture device...
   ✅ Video preview started on device X
   ✅ Video preview stopped, encoder is initialized
   📹 Step 2: Answering call with vid_cnt=1 (video enabled)...
   ✅ Video call answered successfully with vid_cnt=1
   ```

5. **检查 SDP answer**
   - 应该包含: `m=video [非0端口] RTP/AVP 125`
   - 应该包含: `a=rtpmap:125 H264/90000`

6. **验证视频流**
   - 本机画面：应该显示对方视频 (RemoteVideoManager)
   - 对方画面：应该显示本机视频 (PortSIP UC Client)

---

## 回退方案

如果新方案出现问题，可以回退到 CHANGE_DIR 方案：

```cpp
// Revert to audio-first + re-INVITE approach
call_opt.vid_cnt = 0;
pjsua_call_answer2(call_id, &call_opt, 200, NULL, NULL);

QTimer::singleShot(500, [=]() {
    pjsua_call_vid_strm_op_param param;
    pjsua_call_vid_strm_op_param_default(&param);
    param.med_idx = 1;
    param.dir = PJMEDIA_DIR_ENCODING_DECODING;
    pjsua_call_set_vid_strm(call_id, PJSUA_CALL_VID_STRM_CHANGE_DIR, &param);
});
```

---

## 技术细节

### 为什么预览初始化有效？

1. **编码器资源分配**: `pjsua_vid_preview_start()` 会：
   - 打开视频捕获设备
   - 创建编码器实例
   - 分配内存缓冲区
   - 启动编码管道

2. **状态保持**: 停止预览后：
   - 编码器实例保留（不销毁）
   - 设备句柄保持打开
   - 下次使用无需重新初始化

3. **应答时使用**: `pjsua_call_answer2(vid_cnt=1)` 时：
   - PJSIP 检测到编码器已就绪
   - 直接分配 RTP 端口和资源
   - SDP answer 包含有效视频媒体线

### Payload Type 协商机制

PJSIP 的动态 payload type 处理：

1. **作为 Answerer**:
   - 从 Offer 中选择支持的 codec
   - 使用 Offer 中指定的 payload type
   - 例如：Offer `pt=125` → Answer `pt=125`

2. **作为 Offerer**:
   - 使用本地配置的默认 payload types
   - H.264 默认: `96, 100, 99, 97`
   - 对方在 Answer 中选择

3. **re-INVITE 问题**:
   - 初始接听时是 Answerer (应该用对方的 pt)
   - re-INVITE 时变成 Offerer (用自己的 pt)
   - 导致 payload type 不一致

---

## 相关文件

### 修改的文件
- `src/sip_phone/SipPhoneManager.cpp` (行 1534-1614)
- `src/sip_phone/VideoCallManager.h` (行 105)

### 涉及的关键函数
- `SipPhoneManager::answerCall()` - 接听呼叫逻辑
- `pjsua_vid_preview_start()` - 启动预览初始化编码器
- `pjsua_vid_preview_stop()` - 停止预览但保留编码器状态
- `pjsua_call_answer2()` - 应答呼叫

### 相关文档
- [视频来电三按钮修复_最终方案.md](视频来电三按钮修复_最终方案.md)
- [视频性能优化_AsyncProcessing_v6_2025-12-10.md](视频性能优化_AsyncProcessing_v6_2025-12-10.md)

---

## 下一步

如果测试成功：
1. ✅ 视频呼叫功能完全正常
2. ✅ 与 miniSIPServer 完全兼容
3. ✅ 可以开始优化视频性能（目标 30-60 FPS）

如果仍有问题：
1. 检查 SDP 协商日志
2. 检查 RTP 统计信息 (TX pt)
3. 抓包分析实际 RTP payload type
4. 可能需要在 PJSIP 源码层面修复 payload type 映射

---

## 编译时间

**本次编译**: 48.8 秒
**命令**:
```bash
cmake.exe --build build --target belt_control_system -j4
```
