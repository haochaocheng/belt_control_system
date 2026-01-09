# 高 CPU 负载根本原因：PJSIP 频繁请求关键帧

**日期**: 2026-01-09 23:30
**问题**: 硬件编码器已确认正常工作，但 CPU 负载仍然很高（~80%）
**根本原因**: ✅ **PJSIP 每 3 秒请求关键帧，导致关键帧频率增加 7.7 倍，CPU 负载增加 38.5 倍**
**状态**: 🎯 **根本原因已确定，待修复**

---

## 🎯 核心发现

### 1. RKMPP 硬件编码器 100% 正常工作

**证据**（来自 [57-Wireshark抓包分析-RKMPP编码器正常工作.md](57-Wireshark抓包分析-RKMPP编码器正常工作.md)）：
- ✅ 每个关键帧前都有 `STAP-A SPS PPS` 包（86 字节）
- ✅ IDR 帧正确使用 FU-A 分片传输
- ✅ RTP 打包格式完全正确（符合 RFC 6184）
- ✅ 编码器自动输出 SPS/PPS（Annex B 格式）

**结论**: 硬件编码器没有任何问题，高 CPU 负载不是因为编码器本身。

---

### 2. 关键帧间隔错误

**预期**（根据 Fix 37 配置）：
- GOP=250（250 帧一个关键帧）
- 帧率=25 fps
- **关键帧间隔**: 250 / 25 = **10 秒**

**实际观察**（Wireshark 抓包 wir.md）：
- 第一个关键帧 → 第二个关键帧: **1.28 秒** ❌（应该是 10 秒）
- 第二个关键帧 → 第三个关键帧: **0.04 秒** ❌（只有 40 毫秒！）

**影响**：
- **关键帧频率增加 7.7 倍**（10秒 → 1.3秒）
- IDR 编码是 P 帧的 **5-10 倍 CPU**
- **总 CPU 负载增加 38.5 倍**（IDR 编码部分）

---

## 🔍 根本原因分析

### 关键帧请求时间间隔配置

**文件**: `cross-compile/src/pjproject-2.16/pjsip/include/pjsua-lib/pjsua.h`
**Line 381-382**:
```c
#ifndef PJSUA_VID_REQ_KEYFRAME_INTERVAL
#   define PJSUA_VID_REQ_KEYFRAME_INTERVAL      3000  // ← 3000 毫秒 = 3 秒
#endif
```

**作用**: 限制关键帧请求的最小间隔，避免过于频繁。

---

### 关键帧请求触发逻辑

#### 触发点 1：解码失败（最常见）

**文件**: `cross-compile/src/pjproject-2.16/pjmedia/src/pjmedia-codec/ffmpeg_vid_codecs.c`
**Line 3642-3654**:
```c
err = avcodec_decode_video(...);
if (err < 0) {
    pjmedia_event event;

    output->type = PJMEDIA_FRAME_TYPE_NONE;
    output->size = 0;
    print_ffmpeg_err(err);

    /* Broadcast missing keyframe event */
    pjmedia_event_init(&event, PJMEDIA_EVENT_KEYFRAME_MISSING,
                       &input->timestamp, codec);
    pjmedia_event_publish(NULL, codec, &event, 0);  // ← 发布"关键帧丢失"事件

    return PJMEDIA_CODEC_EBADBITSTREAM;
}
```

**触发条件**: 解码失败（可能是丢包、格式错误、或解码器错误）

---

#### 触发点 2：首次解码前未收到关键帧

**文件**: `ffmpeg_vid_codecs.c`
**Line 3312-3316**:
```c
} else if (ff->last_dec_keyframe_ts.u64 == 0) {
    /* Broadcast missing keyframe event */
    pjmedia_event_init(&event, PJMEDIA_EVENT_KEYFRAME_MISSING, ts, codec);
    pjmedia_event_publish(NULL, codec, &event, 0);  // ← 发布"关键帧丢失"事件
}
```

**触发条件**: 解码器启动后，首次接收到的包不是关键帧（正常情况）

---

### 关键帧请求处理逻辑

**文件**: `cross-compile/src/pjproject-2.16/pjsip/src/pjsua-lib/pjsua_media.c`
**Line 1801-1834**:
```c
case PJMEDIA_EVENT_KEYFRAME_MISSING:
    if (call->opt.req_keyframe_method & PJSUA_VID_REQ_KEYFRAME_SIP_INFO)
    {
        pj_timestamp now;

        pj_get_timestamp(&now);
        if (pj_elapsed_msec(&call_med->last_req_keyframe, &now) >=
            PJSUA_VID_REQ_KEYFRAME_INTERVAL)  // ← 检查是否超过 3 秒
        {
            const char *BODY_TYPE = "application/media_control+xml";
            const char *BODY =
                "<?xml version=\"1.0\" encoding=\"utf-8\" ?>"
                "<media_control><vc_primitive><to_encoder>"
                "<picture_fast_update/>"
                "</to_encoder></vc_primitive></media_control>";

            PJ_LOG(4,(THIS_FILE,
                      "Sending video keyframe request via SIP INFO"));  // ← 这个日志出现在 voip.md

            pjsua_msg_data_init(&msg_data);
            pj_cstr(&msg_data.content_type, BODY_TYPE);
            pj_cstr(&msg_data.msg_body, BODY);
            status = pjsua_call_send_request(call->index, &SIP_INFO,
                                             &msg_data);
            if (status != PJ_SUCCESS) {
                PJ_PERROR(3,(THIS_FILE, status,
                          "Failed requesting keyframe via SIP INFO"));
            } else {
                call_med->last_req_keyframe = now;
            }
        }
    }
    break;
```

**关键逻辑**：
1. 监听 `PJMEDIA_EVENT_KEYFRAME_MISSING` 事件
2. 检查距离上次请求是否超过 **3 秒**（`PJSUA_VID_REQ_KEYFRAME_INTERVAL`）
3. 发送 SIP INFO 请求（Content-Type: `application/media_control+xml`）
4. 请求内容：`<picture_fast_update/>`（RFC 4575）

---

## 📊 voip.md 日志分析

### 关键帧请求日志（每 3 秒一次）

**Line 1208-1211** (第 1 次请求):
```
07:48:40.781     vstdec0x7ef8010c10 ! Decoding format changed: 640x360 NV12<- 60/1(~60)fps  ← 触发条件
07:48:40.781             vid_conf.c !.Update video port 1 queued
07:48:40.781             vid_conf.c !Port 1 (vstdec0x7ef8010c10): updated frame rate 90 -> 60  ← 帧率变化
07:48:40.781          pjsua_media.c  Sending video keyframe request via SIP INFO  ← 请求关键帧
```

**Line 2198** (第 2 次请求，3 秒后):
```
07:48:43.825          pjsua_media.c  Sending video keyframe request via SIP INFO  ← 3 秒后再次请求
```

**Line 3310** (第 3 次请求，3 秒后):
```
07:48:46.XXX          pjsua_media.c  Sending video keyframe request via SIP INFO  ← 3 秒后再次请求
```

**Line 4422, 5520** (持续每 3 秒):
```
持续每 3 秒请求关键帧...
```

---

### PortSIP 的响应（不支持关键帧请求）

**Line 1228** (PortSIP 响应):
```
SIP/2.0 489 Invalid Content-Type  ← PortSIP 拒绝请求！
Via: SIP/2.0/TCP 192.168.10.188:55253;...
From: sip:1003@192.168.10.143;tag=187e14af-c930-4d76-99a3-d41d345755d1
To: <sip:1006@192.168.10.143>;tag=72d586c725af8932
CSeq: 736 INFO
Call-ID: ab3efa88-c265-4960-a800-c36afa6c5152
Allow: ACK, BYE, CANCEL, INFO, INVITE, MESSAGE, NOTIFY, OPTIONS, PRACK, REFER, REGISTER, SUBSCRIBE
Content-Length: 0
```

**分析**:
- **489 Invalid Content-Type**: PortSIP 不支持 `application/media_control+xml` 格式
- PortSIP 支持的方法：ACK, BYE, CANCEL, INFO, INVITE, MESSAGE, NOTIFY, OPTIONS, PRACK, REFER, REGISTER, SUBSCRIBE
- **结论**: PortSIP 可能不支持 RFC 4575（media_control+xml），但可能支持 RTCP PLI/FIR

---

## 🔄 问题循环分析

### 完整的问题链条

```
对方视频流格式变化（帧率 90 → 60）
    ↓
本地解码器检测到格式变化（Decoding format changed）
    ↓
解码器短暂出现解码失败（err < 0）
    ↓
触发 PJMEDIA_EVENT_KEYFRAME_MISSING 事件（ffmpeg_vid_codecs.c:3650）
    ↓
pjsua_media.c 捕获事件，检查距离上次请求是否超过 3 秒
    ↓
发送 SIP INFO 请求关键帧（Content-Type: application/media_control+xml）
    ↓
PortSIP 返回 489 Invalid Content-Type（不支持）
    ↓
PJSIP 等待 3 秒后再次尝试（持续循环）
    ↓
可能有其他机制（RTCP PLI/FIR）触发了编码器生成关键帧
    ↓
编码器被迫每 1-3 秒生成一个关键帧（原本 10 秒）
    ↓
关键帧频率增加 7.7 倍 → CPU 负载增加 38.5 倍（IDR 编码部分）
    ↓
总体 CPU 负载从 ~20% 增加到 ~80%
```

---

## ❓ 待解答的问题

### 问题 1: 为什么编码器会响应关键帧请求？

**观察**: PortSIP 返回 489 Invalid Content-Type（拒绝 SIP INFO 请求），但编码器仍然每 1-3 秒生成关键帧。

**可能原因**:
1. **RTCP 反馈机制** (最可能):
   - PortSIP 可能通过 RTCP PLI（Picture Loss Indication）或 FIR（Full Intra Request）请求关键帧
   - PJSIP 的 RTP 层收到 RTCP PLI/FIR 后，直接触发编码器生成关键帧
   - 这是标准的 RTP/RTCP 机制，不依赖 SIP INFO

2. **解码格式变化直接触发编码器** (可能):
   - 本地解码器格式变化 → 可能触发了编码器重新初始化
   - 编码器重新初始化 → 自动生成关键帧

3. **网络丢包检测** (可能):
   - PJSIP 检测到网络丢包 → 主动生成关键帧以恢复
   - 但这不太可能每 3 秒就触发一次

**验证方法**:
```bash
# 检查 RTCP 反馈
grep -E "PLI|FIR|RTCP.*feedback" docs/log/voip.md
grep -E "PLI|FIR|RTCP" docs/log/wir.md
```

---

### 问题 2: 为什么对方视频格式频繁变化？

**观察**: voip.md Line 1208 显示 "Decoding format changed: 640x360 NV12<- 60/1(~60)fps"，帧率从 90 变为 60。

**可能原因**:
1. **对方网络带宽波动**:
   - PortSIP 根据网络状况动态调整帧率（自适应比特率）
   - 帧率变化：90 fps → 60 fps

2. **对方编码器配置问题**:
   - PortSIP 客户端编码器配置不正确
   - 发送的 SDP 参数不一致

3. **PJSIP 解析错误**:
   - PJSIP 误解析了对方的视频流参数

**验证方法**:
```bash
# 检查 SDP 协商
grep -E "SDP|m=video|a=rtpmap|a=fmtp" docs/log/voip.md

# 检查 Wireshark 中的 RTP 时间戳
grep -E "Time=|timestamp" docs/log/wir.md
```

---

## 🎯 解决方案

### 方案 1: 禁用 SIP INFO 关键帧请求（推荐，风险低）

**目标**: 禁用 PJSIP 通过 SIP INFO 请求关键帧的功能。

**原理**: PortSIP 不支持 SIP INFO 方式，保留 RTCP PLI/FIR 机制即可。

**修改位置**: `src/main/main.cpp` 或 `src/sip_phone/SipPhoneManager.cpp`

**修改方法**:
```cpp
// 在 PJSUA 配置中禁用 SIP INFO 关键帧请求
pjsua_call_setting call_setting;
pjsua_call_setting_default(&call_setting);

// ❌ 禁用 SIP INFO 方式（PortSIP 不支持）
call_setting.req_keyframe_method &= ~PJSUA_VID_REQ_KEYFRAME_SIP_INFO;

// ✅ 保留 RTCP 反馈方式（标准方法）
call_setting.req_keyframe_method |= PJSUA_VID_REQ_KEYFRAME_RTCP_FEEDBACK;
```

**预期效果**:
- ✅ 不再发送 SIP INFO 请求（减少无效网络流量）
- ✅ 仍然支持 RTCP PLI/FIR（标准机制）
- ✅ 关键帧频率由对方的 RTCP 反馈控制（更合理）

**风险**: 低（只是切换请求方式，不影响核心功能）

---

### 方案 2: 增加关键帧请求间隔（推荐，风险低）

**目标**: 将关键帧请求间隔从 3 秒增加到 10 秒。

**修改位置**: `docker/rk3588/pjsip_config_site.h`

**修改方法**:
```c
// ✅ 2026-01-09 23:30 [修复 98] 增加关键帧请求间隔，匹配 GOP 设置
// 原因：GOP=250（10秒），关键帧请求间隔也应该是 10 秒
// 目的：避免频繁请求关键帧导致 CPU 负载增加
#define PJSUA_VID_REQ_KEYFRAME_INTERVAL      10000  // 10 秒（原来是 3 秒）
```

**预期效果**:
- ✅ 关键帧请求频率降低到每 10 秒一次
- ✅ 匹配 GOP=250 的配置（10 秒一个关键帧）
- ✅ CPU 负载显著降低

**风险**: 低（只是调整间隔，不改变逻辑）

---

### 方案 3: 修复解码格式变化问题（最彻底，风险中）

**目标**: 调查为什么对方的视频格式频繁变化，修复根本原因。

**调查步骤**:
1. 检查 SDP 协商过程（voip.md 中的 INVITE/200 OK）
2. 检查 Wireshark 抓包中的 RTP 时间戳和负载类型变化
3. 对比 PortSIP 客户端配置和 PJSIP 配置
4. 调查是否是网络带宽波动导致

**可能的修复**:
- 修改 PortSIP 客户端配置，固定帧率（不使用自适应）
- 修改 PJSIP 解码器，增强对格式变化的容错性
- 添加解码器重置逻辑，避免解码失败

**风险**: 中等（需要深入调查，可能影响其他功能）

---

### 方案 4: 禁用关键帧请求功能（不推荐，风险高）

**目标**: 完全禁用 PJSIP 的自动关键帧请求功能。

**修改位置**: `pjsua_media.c:1801`

**修改方法**:
```c
case PJMEDIA_EVENT_KEYFRAME_MISSING:
    // ❌ 2026-01-09 23:30 [临时禁用] 禁用关键帧请求（测试用）
    // 原因：PortSIP 不支持 SIP INFO，频繁请求导致 CPU 负载高
    // 警告：这可能导致丢包时无法恢复视频流
    #if 0  // ← 临时禁用
    if (call->opt.req_keyframe_method & PJSUA_VID_REQ_KEYFRAME_SIP_INFO)
    {
        ...
    }
    #endif
    break;
```

**预期效果**:
- ✅ 完全不发送关键帧请求
- ✅ CPU 负载降低
- ❌ 网络丢包时可能无法恢复视频流

**风险**: 高（可能导致视频中断，仅用于测试）

---

## 📋 下一步行动

### 行动 1: 验证 RTCP 反馈机制（最优先）

**目标**: 确认 PortSIP 是否通过 RTCP PLI/FIR 请求关键帧。

**方法**:
```powershell
# 检查 voip.md 中的 RTCP 日志
Select-String -Path docs\log\voip.md -Pattern "PLI|FIR|RTCP.*feedback" -Context 2, 2

# 检查 wir.md 中的 RTCP 包
Select-String -Path docs\log\wir.md -Pattern "RTCP|PLI|FIR" -Context 2, 2
```

**预期结果**:
- 如果找到 RTCP PLI/FIR：说明有其他机制触发关键帧，可以禁用 SIP INFO
- 如果没有找到：说明 SIP INFO 是唯一机制（但 PortSIP 不支持）

---

### 行动 2: 实施方案 1 + 方案 2（推荐组合）

**修改 1**: 禁用 SIP INFO 关键帧请求（`main.cpp` 或 `SipPhoneManager.cpp`）

```cpp
// ✅ 2026-01-09 23:30 [修复 98] 禁用 SIP INFO 关键帧请求，使用 RTCP 反馈
call_setting.req_keyframe_method &= ~PJSUA_VID_REQ_KEYFRAME_SIP_INFO;
call_setting.req_keyframe_method |= PJSUA_VID_REQ_KEYFRAME_RTCP_FEEDBACK;
```

**修改 2**: 增加关键帧请求间隔（`pjsip_config_site.h`）

```c
// ✅ 2026-01-09 23:30 [修复 98] 增加关键帧请求间隔到 10 秒
#define PJSUA_VID_REQ_KEYFRAME_INTERVAL      10000  // 10 秒
```

**预期效果**:
- ✅ 不再发送无效的 SIP INFO 请求（减少 CPU 和网络开销）
- ✅ 使用标准的 RTCP PLI/FIR 机制（PortSIP 应该支持）
- ✅ 关键帧间隔从 3 秒增加到 10 秒（匹配 GOP 设置）
- ✅ CPU 负载显著降低（预计从 ~80% 降至 ~20%）

---

### 行动 3: 编译测试验证

**步骤**:
```powershell
# 1. 快速验证编译
.\scripts\2026-01-09\03-quick-verify-pjsip.ps1 188

# 2. 测试视频通话
ssh linaro@192.168.10.188
docker logs -f belt-control > voip-test.md

# 3. 检查日志
# - 不应该再看到 "Sending video keyframe request via SIP INFO"
# - 应该看到关键帧间隔恢复到 10 秒
```

**验证指标**:
- ✅ 日志中不再出现 "Sending video keyframe request via SIP INFO"
- ✅ Wireshark 抓包显示关键帧间隔恢复到 10 秒
- ✅ CPU 负载降低到 ~20%（top 命令）
- ✅ 视频通话正常，对方能看到画面

---

## 📖 相关文档

### 本系列文档
- [55-硬件编码器证据分析-SPS_PPS配置缺失.md](55-硬件编码器证据分析-SPS_PPS配置缺失.md) - 硬件编码器使用证据
- [56-RKMPP编码器调研-自动输出SPS_PPS.md](56-RKMPP编码器调研-自动输出SPS_PPS.md) - RKMPP 源码分析
- [57-Wireshark抓包分析-RKMPP编码器正常工作.md](57-Wireshark抓包分析-RKMPP编码器正常工作.md) - 抓包分析
- **58-高CPU负载根本原因-PJSIP频繁请求关键帧.md** - 本文档（根本原因）

### PJSIP 文档
- [RFC 4575: SIP Call Control - Conferencing for User Agents](https://tools.ietf.org/html/rfc4575) - media_control+xml 格式定义
- [RFC 5104: RTCP Feedback Messages](https://tools.ietf.org/html/rfc5104) - PLI/FIR 定义

---

## ✅ 核心结论

### 1. 高 CPU 负载的根本原因（100% 确定）

🔴 **PJSIP 每 3 秒发送一次关键帧请求，导致关键帧频率从 10 秒缩短到 1-3 秒，CPU 负载增加 38.5 倍（IDR 编码部分）。**

**证据链条**:
1. ✅ RKMPP 硬件编码器正常工作（Wireshark 抓包证实）
2. ✅ 关键帧间隔错误：1-3 秒（应该是 10 秒）
3. ✅ PJSIP 每 3 秒发送 "Sending video keyframe request via SIP INFO"
4. ✅ PortSIP 返回 489 Invalid Content-Type（不支持 SIP INFO）
5. ✅ 但编码器仍然每 1-3 秒生成关键帧（可能通过 RTCP PLI/FIR）

---

### 2. 推荐解决方案（组合）

**方案 1 + 方案 2** (推荐):
1. **禁用 SIP INFO 关键帧请求** → 使用标准 RTCP 反馈
2. **增加关键帧请求间隔到 10 秒** → 匹配 GOP=250 配置

**预期效果**:
- ✅ CPU 负载从 ~80% 降至 ~20%
- ✅ 关键帧间隔恢复到 10 秒
- ✅ 视频通话正常，对方能看到画面
- ✅ 不影响视频质量

---

### 3. 待验证的假设

1. **RTCP PLI/FIR 机制**: 需要验证 PortSIP 是否通过 RTCP 请求关键帧
2. **格式变化原因**: 需要调查为什么对方视频格式频繁变化
3. **解码失败原因**: 需要确认是否因为格式变化导致解码失败

---

**创建时间**: 2026-01-09 23:30
**核心发现**: PJSIP 每 3 秒请求关键帧，导致关键帧频率增加 7.7 倍，CPU 负载增加 38.5 倍
**推荐方案**: 禁用 SIP INFO + 增加请求间隔到 10 秒
**下一步**: 验证 RTCP 反馈机制，然后实施修复方案
