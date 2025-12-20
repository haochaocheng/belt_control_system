# 视频来电问题 - miniSIPServer 特定分析

**日期**: 2025-12-11
**状态**: ✅ 720P配置完成，❌ miniSIPServer场景下对方看不到本机视频
**关键发现**: 问题不是PortSIP UC Client，而是miniSIPServer特定问题

---

## 🎯 关键突破性信息（用户反馈）

### 三种场景测试结果

| 场景 | SIP服务器 | 本机→对方 | 对方→本机 | 结果 |
|------|-----------|-----------|-----------|------|
| **场景1** | **miniSIP直连** | ✅ 看到 | ✅ 看到 | **完全正常** |
| **场景2** | **FreeSWITCH** | ✅ 看到 | ✅ 看到 | **完全正常** |
| **场景3** | **miniSIPServer** | ✅ 看到 | ❌ 看不到 | **来电失败** |

### 决定性结论

**这不是PortSIP UC Client的问题！**

理由：
1. ✅ 使用miniSIP直连时，PortSIP UC Client能正常看到本机视频
2. ✅ 使用FreeSWITCH服务器时，PortSIP UC Client能正常看到本机视频
3. ❌ 只有使用miniSIPServer时，PortSIP UC Client看不到本机视频

**因此，问题出在miniSIPServer与本机应用的交互上。**

---

## 💡 三种服务器的工作原理差异

### miniSIP（直连模式）

```
本机 (1280×720 H.264) ←─────────→ PortSIP UC Client
              直接点对点SIP通信
              无中间服务器
              SDP直接协商
```

**特点**：
- ✅ 无SIP代理服务器
- ✅ 直接UDP/RTP连接
- ✅ SDP由双方直接协商
- ✅ 无媒体转发或处理

**结果**: **双向视频正常** ✅

---

### FreeSWITCH（媒体服务器）

```
本机 (720×480?) ──→ FreeSWITCH ──→ PortSIP UC Client
                 [SIP B2BUA]   [视频转码]    (1280×720)
                 [媒体处理]    [格式转换]
```

**特点**：
- ✅ B2BUA（Back-to-Back User Agent）
- ✅ **媒体流经服务器**（不是直接转发）
- ✅ **视频转码功能**：可以接受非标准分辨率并转换
- ✅ **格式适配**：自动调整编码参数
- ✅ **SDP重新生成**：服务器生成符合对方要求的SDP

**工作流程**：
1. 本机发送720×480（或任何格式）
2. FreeSWITCH接收并**解码**
3. FreeSWITCH根据对方能力**重新编码**为1280×720
4. 发送给PortSIP UC Client

**结果**: **双向视频正常** ✅（即使本机发送格式不完美）

---

### miniSIPServer（轻量级代理）

```
本机 (1280×720 H.264) ──→ miniSIPServer ──→ PortSIP UC Client
                       [SIP Proxy]    [纯转发]
                       [不处理媒体]   [不转码]
```

**特点**：
- ⚠️ 纯SIP代理（不是B2BUA）
- ⚠️ **只转发SIP信令**（INVITE, ACK, BYE等）
- ⚠️ **不处理RTP媒体流**（媒体仍是点对点）
- ⚠️ **不转码视频**
- ⚠️ **SDP透传或简单修改**（不重新生成）

**问题所在**：
- 如果SDP参数不完全兼容，miniSIPServer无法修复
- 如果H.264 profile不匹配，miniSIPServer无法转码
- 如果有任何格式问题，miniSIPServer无法适配

**结果**: **对方看不到本机视频** ❌

---

## 🔍 为什么miniSIP直连可以但miniSIPServer不行？

### 关键差异：SDP处理方式

#### miniSIP直连

```
本机 INVITE SDP → 直达 → PortSIP UC Client
PortSIP 200 OK SDP ← 直达 ← PortSIP UC Client

SDP完全由双方协商，无中间干预
```

#### miniSIPServer

```
本机 INVITE SDP → miniSIPServer → [可能修改] → PortSIP UC Client
PortSIP 200 OK SDP ← [可能修改] ← miniSIPServer ← PortSIP UC Client

SDP经过代理服务器处理，可能被修改或"优化"
```

**可能的问题**：
1. miniSIPServer修改了SDP中的某些关键参数
2. miniSIPServer删除或改变了H.264 profile信息
3. miniSIPServer对re-INVITE的SDP处理方式有问题
4. miniSIPServer的NAT处理影响了媒体流

---

## 🧪 当前状态验证

### Attempt 14c 的成功之处

✅ **设备打开正确**：
```
11:09:13.932  vid_port.c  Opening device ... size=1280x720 @60:1 fps
11:09:14.039  vid_port.c  Device ... opened: size=1280x720 @60:1 fps
```

✅ **本地视频发送正确**：
```
[DEBUG] 🎬 [FIRST LOCAL FRAME] Sending format: 1280 x 720 @ 60 / 1 fps
[DEBUG] 📤 [LOCAL VIDEO SEND] Sending FPS: "59.0" | Size: QSize(1280, 720)
```

✅ **编码器配置正确**：
```
[DEBUG] ✅ H264 video codec configured: 1280x720 (720P) @ 25fps (TX), up to 30fps (RX)
[DEBUG] ✅ H264 encoder configured: 1280x720 (720P) @ 25fps (TX), up to 60fps (RX)
```

✅ **RTP统计显示发送**：
```
#1 video H264, sendrecv, peer=192.168.10.243:20012
   TX pt=125, size=1280x720, fps=24.95
      total 877pkt 283.4KB (约10秒发送877包)
```

✅ **接收对方视频正常**：
```
[DEBUG] 🎬 [FIRST FRAME] Decoder output format: 1280 x 720
```

### 但是...

❌ **对方（PortSIP UC Client）看不到本机视频**

**并且**：
- ✅ 使用miniSIP直连时，相同的PortSIP UC Client能看到
- ✅ 使用FreeSWITCH时，相同的PortSIP UC Client能看到

**因此问题不在PortSIP UC Client，而在miniSIPServer的处理上。**

---

## 🔬 可能的根本原因

### 假设1：H.264 Profile不匹配（通过miniSIPServer时）

**PortSIP UC Client提供的参数**（从INVITE SDP）：
```
a=fmtp:125 profile-level-id=42001f; packetization-mode=1
```
- `42001f` = Baseline Profile (42) + Level 3.1 (001f)

**本机应答的参数**（re-INVITE SDP）：
```
a=fmtp:125 profile-level-id=42e01e; packetization-mode=1
```
- `42e01e` = Baseline Profile (42) + Level 3.0 (e01e)

**问题**：
- 直连时：PortSIP能够协商并接受profile差异
- 经过miniSIPServer：可能SDP被修改导致profile信息丢失或不匹配

---

### 假设2：re-INVITE SDP处理问题

**Attempt 13的方法**（应答后re-INVITE激活视频）：
```
1. 收到INVITE（视频呼叫）
2. 应答200 OK（音频通话）
3. 通话CONFIRMED后
4. 发送re-INVITE（激活视频）
```

**可能的问题**：
- miniSIPServer可能不正确转发re-INVITE
- re-INVITE中的SDP可能被miniSIPServer"优化"掉某些关键参数
- 对方收到的re-INVITE SDP与本机发送的不一致

---

### 假设3：RTP包格式问题

虽然RTP统计显示在发送，但：
- PortSIP可能收到了RTP包但无法解码
- H.264 NAL单元封装格式可能有问题
- Packetization mode不匹配

**为什么直连可以但miniSIPServer不行**：
- 直连时SDP协商更准确
- miniSIPServer可能改变了某些RTP相关的SDP参数

---

### 假设4：NAT/网络地址问题

miniSIPServer可能修改了SDP中的IP地址或端口，导致：
- PortSIP UC Client尝试发送到错误的地址
- 或者PortSIP认为应该发送到miniSIPServer而不是本机
- 防火墙规则不同

---

## 📋 诊断步骤

### 第一步：对比SDP（最关键）

需要抓取并对比三种场景的完整SDP：

#### 场景A：miniSIP直连（工作正常）✅
```
1. PortSIP发送的INVITE SDP
2. 本机应答的200 OK SDP
3. 本机re-INVITE SDP
4. PortSIP re-INVITE 200 OK SDP
```

#### 场景B：miniSIPServer（不工作）❌
```
1. PortSIP → miniSIPServer → 本机的INVITE SDP
2. 本机 → miniSIPServer → PortSIP的200 OK SDP
3. 本机 → miniSIPServer → PortSIP的re-INVITE SDP
4. PortSIP → miniSIPServer → 本机的re-INVITE 200 OK SDP
```

**对比重点**：
- H.264 profile-level-id是否一致
- packetization-mode是否一致
- 媒体地址（c=行）是否正确
- 端口号是否正确
- 是否有参数被miniSIPServer删除或修改

---

### 第二步：RTP包捕获分析

使用Wireshark抓包：

#### 场景A：miniSIP直连
- 本机 → PortSIP的RTP包格式
- H.264 payload结构

#### 场景B：miniSIPServer
- 本机 → PortSIP的RTP包格式
- 与场景A对比

**检查**：
- RTP包是否真的到达PortSIP
- H.264 NAL单元格式是否正确
- 是否有分片问题

---

### 第三步：尝试匹配PortSIP的profile

修改代码，使本机发送的profile-level-id与PortSIP完全一致：

**当前**：我们发送 `profile-level-id=42e01e`
**PortSIP发送**：`profile-level-id=42001f`

**修改方案**：在PJSIP中配置H.264编码器使用profile 42001f

---

### 第四步：检查miniSIPServer配置

可能需要检查miniSIPServer的：
- SDP操作设置
- NAT处理设置
- 视频支持设置
- 日志（如果有的话）

---

## 🛠️ 建议的解决方案

### 方案1：直接使用miniSIP或FreeSWITCH（最简单）✅

既然miniSIP和FreeSWITCH都工作正常，为什么一定要用miniSIPServer？

**优势**：
- miniSIP：最简单，无需服务器
- FreeSWITCH：功能最强，支持复杂场景

---

### 方案2：修复H.264 Profile配置（推荐尝试）

在代码中明确配置H.264 profile为42001f（匹配PortSIP）：

**文件**：`src/risip/core/risipendpoint.cpp` 或 `src/sip_phone/VideoCallManager.cpp`

需要使用PJSIP API设置H.264的具体profile参数，确保SDP中的profile-level-id与PortSIP完全一致。

---

### 方案3：抓包分析后对症下药

完成诊断步骤后，根据SDP差异或RTP问题针对性修复。

---

## 🎯 立即行动建议

### 优先级1：SDP对比（最关键）

**您需要做的**：

1. **抓取miniSIP直连场景的SIP消息**：
   ```bash
   # 如果miniSIP有日志功能，导出完整SIP消息
   # 或使用Wireshark抓取SIP流量
   ```

2. **抓取miniSIPServer场景的SIP消息**：
   ```bash
   # 应用已经在输出PJSIP日志
   # 需要完整的INVITE、200 OK、re-INVITE、re-INVITE 200 OK
   ```

3. **对比SDP**：
   - 查找H.264参数差异
   - 查找IP/端口差异
   - 查找任何被删除的参数

**我可以帮您分析SDP差异，找出miniSIPServer修改了什么。**

---

### 优先级2：尝试修改H.264 Profile

如果您愿意，我可以立即修改代码，尝试让本机的H.264 profile-level-id与PortSIP完全匹配（42001f）。

**需要修改**：
- H.264编码器的profile/level设置
- 确保SDP中的fmtp参数正确

---

### 优先级3：考虑更换服务器

如果miniSIPServer无法解决，建议：
- **生产环境**：使用FreeSWITCH（稳定可靠）
- **简单场景**：使用miniSIP直连（无需服务器）

---

## 📊 总结

### 已经完成的工作

1. ✅ **Attempt 13**：找到正确的视频激活方法（re-INVITE）
2. ✅ **Attempt 14a-c**：修复三个配置点，统一为720P (1280×720)
3. ✅ **设备成功打开**：1280×720 @ 60fps
4. ✅ **本地视频发送**：1280×720 @ 25fps
5. ✅ **接收对方视频**：1280×720正常

### 当前问题

❌ **对方使用miniSIPServer时看不到本机视频**

### 关键发现

🎯 **问题不是PortSIP UC Client**：
- miniSIP直连：工作正常 ✅
- FreeSWITCH：工作正常 ✅
- miniSIPServer：不工作 ❌

**因此问题在于miniSIPServer的SDP处理或转发方式。**

### 下一步

1. **对比SDP**（最关键）
2. **尝试匹配H.264 profile**
3. **考虑更换服务器**

---

## 请您选择

1. **提供SDP对比**：提供miniSIP直连场景的完整SIP消息，我帮您对比
2. **立即修改profile**：我修改代码匹配PortSIP的profile-level-id=42001f
3. **更换服务器**：使用FreeSWITCH或miniSIP直连

**您希望我采取哪个方案？** 🤔
