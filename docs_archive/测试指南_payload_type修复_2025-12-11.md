# 测试指南 - Payload Type 修复验证

**日期**: 2025-12-11
**目标**: 验证对方（PortSIP UC Client）能否看到本机视频

---

## 快速测试步骤

### 1. 启动应用
```bash
cd e:\2025\3_gongkongji\belt_control_system
.\build\bin_windows\belt_control_system.exe
```

### 2. 从 PortSIP 发起视频呼叫
- 确保 PortSIP UC Client 连接到 miniSIPServer
- 发起视频通话到本应用

### 3. 接听视频呼叫
- 点击"接听视频"按钮

### 4. 验证效果

#### ✅ 成功标志
1. **呼叫不会立即挂断**（之前会在 0.3 秒后挂断）
2. **本机能看到对方视频**（RemoteVideoManager 显示画面）
3. **对方能看到本机视频**（PortSIP UC Client 显示画面）← **这是本次修复的重点！**

#### ❌ 失败标志
- 呼叫立即挂断（miniSIPServer 发送 BYE）
- 对方看不到本机视频
- SDP answer 中 `m=video 0`

---

## 日志检查点

### 关键日志（成功）
```
📹 [VIDEO CALL] Initializing video encoder before answering...
📹 Step 1: Pre-initializing video capture device...
✅ Video preview started on device 0
✅ Video preview stopped, encoder is initialized
📹 Step 2: Answering call with vid_cnt=1 (video enabled)...
✅ Video call answered successfully with vid_cnt=1
```

### SDP Answer 检查（成功）
应该包含：
```
m=video 4002 RTP/AVP 125    ← 端口不为 0，pt=125
a=rtpmap:125 H264/90000
```

不应该包含：
```
m=video 0 RTP/AVP 0    ← 端口为 0 表示失败
```

### RTP 统计检查（1 秒后）
```
📹 Step 3: Checking video stream status after answer...
   Call state: CONFIRMED
   Call media_cnt: 2
   Media 0: type=0 (audio) ...
   Media 1: type=1 (video) dir=3 status=1
   ✅ Video stream 1 is ACTIVE
```

---

## 对比测试（可选）

### 之前的问题（re-INVITE 方案）
| 项目 | 本机 | 对方（PortSIP） |
|------|------|----------------|
| 接收视频 | ✅ 正常 (~12 FPS) | ✅ 正常 |
| 发送视频 | ✅ 发送 764KB | ❌ **看不到** |
| Payload Type | 接收 pt=125<br>发送 pt=100 | 期望 pt=125<br>收到 pt=100 ❌ |

### 预期效果（本次修复）
| 项目 | 本机 | 对方（PortSIP） |
|------|------|----------------|
| 接收视频 | ✅ 正常 | ✅ **正常** ← 修复目标 |
| 发送视频 | ✅ 发送数据 | ✅ **能看到** ← 修复目标 |
| Payload Type | 协商 pt=125<br>发送 pt=125 ✅ | 期望 pt=125<br>收到 pt=125 ✅ |

---

## 如果仍有问题

### 1. 检查 SDP 协商
查找日志中的 SDP 内容：
```
TX [号码] SIP/2.0 200 OK
...
m=video [端口] RTP/AVP [payload_types]
a=rtpmap:[pt] H264/90000
```

关键检查：
- 端口是否为 0？
- Payload type 是否为 125？

### 2. 检查视频统计
呼叫建立 5-10 秒后，查看 PJSIP 统计：
```
TX pt=[?], size=720x480, fps=[?]
total [?]pkt [?]KB
```

关键检查：
- TX pt 应该是 125（不是 100）
- fps 应该 > 0
- 数据包和字节数应该持续增长

### 3. 抓包分析（高级）
如果对方仍看不到视频，可以用 Wireshark 抓包：
```
过滤器: rtp && ip.dst == [对方IP]
```

检查 RTP 包：
- Payload Type 字段应该是 125
- 包大小应该 > 100 字节（不是空包）
- 包应该持续发送（不是偶发）

### 4. 对比 FreeSWITCH
用户提到之前用 FreeSWITCH 时视频正常（但只有 15 FPS）：
- 可以临时切回 FreeSWITCH 验证功能
- 对比 SDP 协商过程
- 找出 miniSIPServer 的特殊之处

---

## 预期时间线

| 阶段 | 时间 | 说明 |
|------|------|------|
| 应用启动 | 0s | |
| 收到来电 | +2s | 显示三按钮界面 |
| 编码器初始化 | +0.1s | 预览启动/停止 |
| 发送 200 OK | +0s | SDP answer 包含视频 |
| 媒体流建立 | +0.5s | 开始接收视频 |
| **对方看到视频** | **+1s** | **本次修复目标** |
| 视频稳定 | +3s | 双向视频流畅 |

---

## 成功后的下一步

✅ 如果测试成功：
1. 视频呼叫功能完全正常
2. miniSIPServer 兼容性问题已解决
3. 可以开始优化视频性能（目标 30-60 FPS）
   - 当前约 12-15 FPS（接收）
   - 目标 30-60 FPS（与 miniSIPServer 配合）

❌ 如果仍有问题：
1. 提供完整日志（包括 SDP 协商）
2. 提供 RTP 统计信息
3. 可能需要抓包分析
4. 考虑在 PJSIP 源码层面调试

---

## 相关文档
- [视频来电payload_type修复_初始化编码器方案_2025-12-11.md](视频来电payload_type修复_初始化编码器方案_2025-12-11.md) - 详细技术说明
