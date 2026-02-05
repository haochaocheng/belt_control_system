# TCP 音频协议 Wireshark 抓包过滤指南

**创建时间**：2026-01-22 19:30
**文档版本**：v1.0
**适用场景**：分析 TCP 音频传输协议（UDP 发现 + TCP + WebSocket + Opus）

---

## 一、网络拓扑

```
宿主机（上位机软件）
    ↓ UDP 广播 (端口 8600)
    ↓ TCP 服务器 (端口 7800)
    |
    ├─→ 192.168.10.188 (RK3588 开发设备，新客户端)
    └─→ 192.168.10.98  (音频模块，参考实现，正常工作)
```

---

## 二、协议流程

### 阶段 1: UDP 服务发现（端口 8600）
```json
上位机 → 广播: {"voiceport": 7800, "voicev4": [-1062731588, -1062731589]}
```

### 阶段 2: TCP 连接 + WebSocket 握手
```
客户端 → 服务器: TCP SYN (端口 7800)
客户端 → 服务器: HTTP Upgrade to WebSocket
服务器 → 客户端: HTTP 101 Switching Protocols
```

### 阶段 3: WebSocket 协议
```json
客户端 → 服务器: TEXT 帧 {"cmd": 1, "id": 0, "uuid": "Init", ...}
服务器 → 客户端: TEXT 帧 {"cmd": 1, "id": 123, "uuid": "abc-def", ...}
```

### 阶段 4: 心跳机制
```
客户端 → 服务器: PING 帧 (每 5 秒)
服务器 → 客户端: PONG 帧 (2 秒超时)
```

### 阶段 5: Opus 音频数据
```
客户端 → 服务器: BINARY 帧 (Opus 20ms 帧，16kbps)
```

---

## 三、Wireshark 过滤规则

### 🔥 **推荐过滤规则（综合）**

#### 1. **查看所有 TCP 音频流量（两个设备）**
```wireshark
(udp.port == 8600) or (ip.addr == 192.168.10.188 and tcp.port == 7800) or (ip.addr == 192.168.10.98 and tcp.port == 7800)
```

#### 2. **只看 192.168.10.188（开发设备）**
```wireshark
(udp.port == 8600) or (ip.addr == 192.168.10.188 and tcp.port == 7800)
```

#### 3. **只看 192.168.10.98（参考设备）**
```wireshark
(udp.port == 8600) or (ip.addr == 192.168.10.98 and tcp.port == 7800)
```

#### 4. **对比两个设备的流量**
```wireshark
(udp.port == 8600) or ((ip.addr == 192.168.10.188 or ip.addr == 192.168.10.98) and tcp.port == 7800)
```

---

### 🔍 **分阶段过滤规则**

#### 阶段 1: UDP 服务发现
```wireshark
udp.port == 8600
```
**期望看到**：
- JSON 数据：`{"voiceport": 7800, "voicev4": [...]}`

#### 阶段 2: TCP 三次握手
```wireshark
ip.addr == 192.168.10.188 and tcp.flags.syn == 1 and tcp.port == 7800
```
**期望看到**：
- SYN → SYN-ACK → ACK

#### 阶段 3: WebSocket 握手
```wireshark
ip.addr == 192.168.10.188 and tcp.port == 7800 and (http.request or http.response)
```
**期望看到**：
- HTTP Upgrade 请求：`Upgrade: websocket`
- HTTP 101 响应：`101 Switching Protocols`

#### 阶段 4: WebSocket TEXT 帧（设备信息 JSON）
```wireshark
ip.addr == 192.168.10.188 and websocket.opcode == 1
```
**期望看到**：
- `{"cmd": 1, "id": 0, "uuid": "Init", ...}`（客户端发送）
- `{"cmd": 1, "id": 123, "uuid": "...", ...}`（服务器响应）

#### 阶段 5: WebSocket PING/PONG（心跳）
```wireshark
ip.addr == 192.168.10.188 and (websocket.opcode == 9 or websocket.opcode == 10)
```
**期望看到**：
- PING 帧（opcode=9，每 5 秒）
- PONG 帧（opcode=10，2 秒内响应）

#### 阶段 6: WebSocket BINARY 帧（Opus 音频）
```wireshark
ip.addr == 192.168.10.188 and websocket.opcode == 2
```
**期望看到**：
- 大量 BINARY 帧，每帧大小约 40-60 字节（Opus 20ms 帧）

---

### 🆚 **对比两个设备的差异**

#### 过滤规则：
```wireshark
((ip.addr == 192.168.10.188 or ip.addr == 192.168.10.98) and tcp.port == 7800)
```

#### Wireshark 统计分析：
1. **统计 → 对话 → TCP**
   - 查看每个设备的连接数、数据量、持续时间

2. **统计 → 协议分层次**
   - 查看 WebSocket 帧类型分布（TEXT、BINARY、PING、PONG）

3. **统计 → IO 图表**
   - 横轴：时间
   - 纵轴：数据包速率
   - 过滤器 1（红色）：`ip.addr == 192.168.10.188 and tcp.port == 7800`
   - 过滤器 2（蓝色）：`ip.addr == 192.168.10.98 and tcp.port == 7800`

---

## 四、关键字段提取

### 1. **UDP JSON 解析**
右键数据包 → 追踪流 → UDP 流

### 2. **WebSocket TEXT 帧解析**
展开：
```
Ethernet II → Internet Protocol → TCP → WebSocket → Text → Data (JSON)
```

### 3. **Opus 音频数据大小**
展开：
```
Ethernet II → Internet Protocol → TCP → WebSocket → Binary → Payload Length
```

---

## 五、常见问题诊断

### 问题 1: UDP 广播未收到
**过滤规则**：
```wireshark
udp.port == 8600
```
**检查**：
- 是否有 UDP 数据包？
- 源 IP 是否正确？
- JSON 格式是否正确？

### 问题 2: TCP 连接失败
**过滤规则**：
```wireshark
ip.addr == 192.168.10.188 and tcp.flags.reset == 1
```
**检查**：
- 是否有 RST 包（连接被拒绝）？
- 三次握手是否完整？

### 问题 3: WebSocket 握手失败
**过滤规则**：
```wireshark
ip.addr == 192.168.10.188 and http.response.code != 101
```
**检查**：
- HTTP 响应码是否为 101？
- Upgrade 头是否正确？

### 问题 4: 心跳超时
**过滤规则**：
```wireshark
ip.addr == 192.168.10.188 and websocket.opcode == 9
```
**检查**：
- PING 帧间隔是否为 5 秒？
- PONG 响应是否在 2 秒内？

### 问题 5: 音频数据未发送
**过滤规则**：
```wireshark
ip.addr == 192.168.10.188 and websocket.opcode == 2 and frame.len > 100
```
**检查**：
- 是否有 BINARY 帧？
- 帧大小是否合理（40-60 字节）？
- 帧率是否为 50fps（20ms 间隔）？

---

## 六、快速开始步骤

### Step 1: 启动 Wireshark
```bash
# 选择网卡（连接到 192.168.10.x 网段的网卡）
```

### Step 2: 应用初始过滤规则
```wireshark
(udp.port == 8600) or ((ip.addr == 192.168.10.188 or ip.addr == 192.168.10.98) and tcp.port == 7800)
```

### Step 3: 启动上位机软件
- 确保 UDP 广播已发送

### Step 4: 启动设备 192.168.10.188（开发设备）
```bash
ssh linaro@192.168.10.188
cd /app
./belt_control_system
```

### Step 5: 启动设备 192.168.10.98（参考设备）
- 正常启动即可

### Step 6: 触发音频播放
- 在上位机软件中播放音频

### Step 7: 停止抓包并分析
- 停止 Wireshark 捕获
- 应用各种过滤规则分析数据

---

## 七、保存和导出

### 1. **保存抓包文件**
```
文件 → 保存 → tcp_audio_capture_2026-01-22.pcapng
```

### 2. **导出特定流**
```
右键数据包 → 追踪流 → TCP 流 → 另存为
```

### 3. **导出 WebSocket JSON**
```
右键 WebSocket TEXT 帧 → 导出分组字节流 → message.json
```

---

## 八、高级技巧

### 1. **彩色标记规则**

#### 绿色：UDP 服务发现
```wireshark
udp.port == 8600
```

#### 蓝色：WebSocket 握手
```wireshark
http.request.method == "GET" and http.upgrade == "websocket"
```

#### 黄色：心跳 PING/PONG
```wireshark
websocket.opcode == 9 or websocket.opcode == 10
```

#### 红色：音频 BINARY 帧
```wireshark
websocket.opcode == 2
```

### 2. **自动刷新显示过滤器**
```
视图 → 自动滚动 → 实时捕获
```

### 3. **时间列显示相对时间**
```
视图 → 时间显示格式 → 自捕获开始的秒数
```

---

## 九、示例输出

### UDP 服务发现包：
```json
Frame 1: 124 bytes on wire (992 bits)
    Source: 192.168.10.100
    Destination: 255.255.255.255
    Protocol: UDP
    Length: 90
    Data: {"voiceport": 7800, "voicev4": [-1062731588, -1062731589]}
```

### WebSocket TEXT 帧（设备信息）：
```json
Frame 45: 350 bytes on wire
    Source: 192.168.10.188
    Destination: 192.168.10.100
    Protocol: WebSocket
    Opcode: Text (1)
    Payload: {"cmd":1,"id":0,"uuid":"Init","name":"皮带控制系统",...}
```

### WebSocket BINARY 帧（Opus 音频）：
```
Frame 123: 85 bytes on wire
    Source: 192.168.10.188
    Destination: 192.168.10.100
    Protocol: WebSocket
    Opcode: Binary (2)
    Payload Length: 48
    Payload: [Opus encoded data]
```

---

## 十、参考文档

- **TCP 音频传输完整实施总结**：`docs/2026-01-22/01-TCP音频传输模式完整实施总结.md`
- **WebSocket RFC 6455**：https://tools.ietf.org/html/rfc6455
- **Opus Audio Codec**：https://opus-codec.org/docs/

---

**备注**：
1. 如果上位机软件使用的端口不是 7800，请根据 UDP JSON 中的 `voiceport` 字段修改过滤规则
2. 192.168.10.98 和 192.168.10.188 的行为应该一致，如有差异即为 bug
3. 抓包时建议同时记录日志（`docs/log/voip.md`）进行对比分析
