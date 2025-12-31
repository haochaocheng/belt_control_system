# SDP 大小优化修复总结（2025-12-31）

## 问题描述

**症状**：1002 ↔ 1006 视频通话无法建立，miniSIP 服务器无响应

**根本原因**：
1. INVITE 消息大小 **1566 字节** 超过 MTU 1500
2. IP 分片导致 miniSIP 服务器无法处理 SIP 消息
3. 32 秒超时后通话失败

## 修复方案

### 1. 删除 Text 媒体（节省 ~40 字节）

**文件**：`cross-compile/src/pjproject-2.16/pjsip/src/pjsua-lib/pjsua_call.c:663-668`

**修改**：
```c
// ✅ 2025-12-31 关键修复:禁用 text/RTT 媒体以减小 SDP 大小
// opt->txt_cnt = 1;  // ← 旧代码(2025-12-31 注释)
opt->txt_cnt = 0;  // ← 新代码:默认禁用 text 媒体
```

**文件**：`src/risip/core/risipcall.cpp:416-422`

**修改**：删除 `PJSUA_CALL_INCLUDE_DISABLED_MEDIA` 标志
```cpp
// ❌ 2025-12-31 删除：PJSUA_CALL_INCLUDE_DISABLED_MEDIA 会强制包含禁用的 text 媒体
// prm.opt.flag |= PJSUA_CALL_INCLUDE_DISABLED_MEDIA;  // ← 旧代码（2025-12-31 删除）
```

**效果**：SDP 中不再包含 `m=text 0 RTP/AVP 0` 行

---

### 2. 删除非必需 RTCP-FB 参数（节省 ~110 字节）

**文件**：`src/risip/core/risipaccountconfiguration.cpp:410-438`

**删除的参数**：
- `a=rtcp-fb:* goog-remb`（Google 带宽估计扩展，~55 字节）
- `a=rtcp-fb:* transport-cc`（传输层拥塞控制，~55 字节）

**保留的必需参数**：
- ✅ `a=rtcp-fb:* nack`（RFC 标准，丢包重传）
- ✅ `a=rtcp-fb:* ccm fir`（RFC 标准，关键帧请求）
- ✅ `a=rtcp-fb:* nack pli`（视频关键帧请求，PJSIP 自动添加）

**修改代码**：
```cpp
// ❌ 2025-12-31 删除：GOOG-REMB 和 TRANSPORT-CC（为了减小 SDP 大小到 MTU 1500 以下）
/*
// 3. GOOG-REMB - Google Receiver Estimated Maximum Bitrate（带宽估计）
cap.codecId = "*";
cap.type = PJMEDIA_RTCP_FB_OTHER;
cap.typeName = "goog-remb";
cap.param = "";
m_data->accountConfig.mediaConfig.rtcpFbConfig.caps.push_back(cap);

// 4. TRANSPORT-CC - Transport-wide Congestion Control（传输层拥塞控制）
cap.codecId = "*";
cap.type = PJMEDIA_RTCP_FB_OTHER;
cap.typeName = "transport-cc";
cap.param = "";
m_data->accountConfig.mediaConfig.rtcpFbConfig.caps.push_back(cap);
*/
```

---

### 3. 禁用 Lock Codec（防止自动 re-INVITE）

**文件**：`src/risip/core/risipaccountconfiguration.cpp:431-441`

**问题**：PJSIP 默认在通话建立后发送 re-INVITE 优化编解码器，导致 miniSIP 错误响应 `a=inactive`

**修改**：
```cpp
// ✅ 2025-12-31 关键修复：禁用 Lock Codec（避免通话后自动 re-INVITE）
m_data->accountConfig.mediaConfig.lockCodecEnabled = false;
```

**效果**：通话建立后不再发送额外的 re-INVITE 消息

---

## 修复效果

### SDP 优化前后对比

| 项目 | 优化前 | 优化后 | 节省 |
|------|--------|--------|------|
| **INVITE 总大小** | 1566 字节 | **1468 字节** | **98 字节** |
| **SDP 大小** | 950 字节 | 851 字节 | 99 字节 |
| **Text 媒体** | `m=text 0 ...` (40 字节) | ❌ 删除 | 40 字节 |
| **goog-remb** | `a=rtcp-fb:* goog-remb` | ❌ 删除 | ~24 字节 |
| **transport-cc** | `a=rtcp-fb:* transport-cc` | ❌ 删除 | ~27 字节 |
| **是否超过 MTU** | ❌ 超过（分片） | ✅ **低于 1500** | - |

### 测试结果验证

**INVITE 消息**（优化后）：
```
TX 1468 bytes Request msg INVITE/cseq=25403
Content-Length:   851

m=audio 4000 RTP/AVP 8 0 96 120 121
a=rtcp-fb:* nack              ← 保留
a=rtcp-fb:* ccm fir           ← 保留

m=video 4002 RTP/AVP 100 96
a=rtcp-fb:* nack pli          ← 保留
a=rtcp-fb:* nack              ← 保留
a=rtcp-fb:* ccm fir           ← 保留
```

**miniSIP 200 OK 响应**：
```
m=video 20202 RTP/AVP 100
a=sendrecv  ← ✅ 关键：不再是 a=inactive！
a=rtcp-fb:100 ccm fir
a=rtcp-fb:100 nack
a=rtcp-fb:100 nack pli
```

**结果**：
- ✅ INVITE < MTU 1500，不再 IP 分片
- ✅ miniSIP 正常响应 200 OK
- ✅ 视频方向为 `a=sendrecv`（之前是 `a=inactive`）
- ✅ 通话成功建立

---

## 关键文件修改列表

### PJSIP 源码修改
1. **cross-compile/src/pjproject-2.16/pjsip/src/pjsua-lib/pjsua_call.c**
   - Line 668: `txt_cnt = 0`（禁用 text 媒体）

### 应用代码修改
2. **src/risip/core/risipcall.cpp**
   - Line 416-422: 删除 `PJSUA_CALL_INCLUDE_DISABLED_MEDIA` 标志

3. **src/risip/core/risipaccountconfiguration.cpp**
   - Line 410-438: 删除 goog-remb 和 transport-cc
   - Line 438: `lockCodecEnabled = false`

4. **docker/rk3588/pjsip_config_site.h**
   - Line 68-72: 添加注释说明（无实际代码修改）

---

## 技术要点

### 为什么删除 goog-remb 和 transport-cc？

**goog-remb（Google REMB）**：
- Google 私有扩展，用于带宽估计
- 非 RFC 标准，可选功能
- miniSIP 不依赖此功能

**transport-cc（传输层拥塞控制）**：
- 用于 WebRTC 拥塞控制
- 非 RFC 标准，可选功能
- SIP 软电话通常不使用

### 为什么保留 nack 和 ccm fir？

**nack（NACK - Negative Acknowledgement）**：
- RFC 4585 标准
- 丢包重传机制，提升通话质量
- 大多数 SIP 客户端支持

**ccm fir（Codec Control Message - Full Intra Request）**：
- RFC 5104 标准
- 请求完整 I 帧，用于视频快速恢复
- 视频通话必需功能

---

## 相关问题记录

### 历史问题
- [2025-12-26] Text 媒体导致 SDP 过大
- [2025-12-27] RTCP-FB 参数过多
- [2025-12-31] Lock Codec 导致 re-INVITE

### 参考文档
- RFC 4585: Extended RTP Profile for RTCP-Based Feedback (RTP/AVPF)
- RFC 5104: Codec Control Messages in the RTP Audio-Visual Profile
- PJSIP 文档: account.hpp AccountMediaConfig.lockCodecEnabled

---

## 编译部署

```powershell
# 统一使用自动化脚本
.\build-ubuntu24-apt.ps1 188
```

**脚本自动完成**：
1. 检测 PJSIP 源码变化 → 重新编译静态库（如需要）
2. 检测 PJSIP 库变化 → 清除应用缓存（如库更新）
3. 交叉编译应用程序
4. 构建 Docker 镜像
5. 部署到设备 188

---

## 验证方法

### 1. 检查 INVITE 大小
```bash
# 在设备 188 上运行
docker logs -f belt_control | grep "TX.*INVITE"
```

**期望输出**：
```
TX 1468 bytes Request msg INVITE  # < 1500 字节
```

### 2. 检查 SDP 内容
```bash
# 验证无 text 媒体
docker logs belt_control | grep "m=text"  # 应无输出

# 验证 RTCP-FB 参数
docker logs belt_control | grep "a=rtcp-fb"
```

**期望输出**：
```
a=rtcp-fb:* nack
a=rtcp-fb:* ccm fir
a=rtcp-fb:* nack pli
```

### 3. 检查通话状态
Wireshark 抓包验证：
- ✅ INVITE 无 IP 分片
- ✅ 收到 200 OK 响应
- ✅ SDP 中 `a=sendrecv`（不是 `a=inactive`）

---

## 总结

通过优化 SDP 大小（删除 text 媒体和非必需 RTCP-FB 参数），成功将 INVITE 消息从 **1566 字节降至 1468 字节**，解决了 IP 分片问题，使得 miniSIP 服务器能够正常处理 SIP 消息，视频通话成功建立。

同时禁用 Lock Codec 功能，避免通话建立后的自动 re-INVITE，防止 miniSIP 错误响应 `a=inactive`。

**关键成功指标**：
- ✅ INVITE < MTU 1500
- ✅ 无 IP 分片
- ✅ miniSIP 正常响应
- ✅ 视频 `a=sendrecv`
- ✅ 无自动 re-INVITE
