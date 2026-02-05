# UDP 服务发现失败分析 - 端口未监听问题

**创建时间**：2026-01-22 20:00
**问题版本**：2026-01-22 13:39:40
**设备 IP**：192.168.10.188
**上位机 IP**：192.168.10.142

---

## 一、问题现象

### 1. Wireshark 抓包数据（wir.md）

#### Frame 5742: UDP 服务发现包（上位机 → 设备）
```
Source:      192.168.10.142:8601
Destination: 192.168.10.188:8600
Protocol:    UDP
Length:      42 bytes
```
✅ **上位机成功发送了 UDP 服务发现包**

#### Frame 5744: ICMP 错误响应（设备 → 上位机）
```
Source:      192.168.10.188
Destination: 192.168.10.142
Protocol:    ICMP
Type:        3 (Destination unreachable)
Code:        3 (Port unreachable)
```
❌ **设备返回端口不可达错误**

### 2. 应用日志（voip.md）

#### 初始化日志
```
[DEBUG] ✅ WebSocketClient 初始化完成
[DEBUG] 📋 加载配置完成:
[DEBUG]    - ID: 0
[DEBUG]    - UUID: "Init"
[DEBUG]    - 名称: "皮带控制系统"
[DEBUG] ✅ AudioNetworkTcpSender 初始化完成
```
✅ **AudioNetworkTcpSender 对象创建成功**

#### 缺失的日志
```
❌ 没有 "启动 UDP 服务发现" 日志
❌ 没有 "UDP socket 绑定成功" 日志
❌ 没有 "监听 UDP 端口 8600" 日志
```

---

## 二、根本原因

### 问题定位

1. **AudioNetworkTcpSender 对象已创建**（voip.md 第100-105行）
2. **但 `startDiscovery()` 方法未被调用**
3. **UDP 端口 8600 没有监听**
4. **上位机发送的 UDP 包无人接收 → ICMP Port Unreachable**

### 代码分析

#### CommonControl.cpp 构造函数（第106行）
```cpp
CommonControl::CommonControl(QObject *parent)
    : QObject(parent)
    , m_audioNetworkSender(new AudioNetworkSender(this))
    , m_audioNetworkTcpSender(new AudioNetworkTcpSender(this))  // ✅ 创建对象
{
    // ❌ 缺少：m_audioNetworkTcpSender->startDiscovery();
}
```

#### AudioNetworkTcpSender::startDiscovery() 方法
```cpp
void AudioNetworkTcpSender::startDiscovery()
{
    // 绑定 UDP 端口 8600
    if (!m_udpSocket->bind(QHostAddress::AnyIPv4, m_udpPort)) {
        qWarning() << "❌ UDP 端口绑定失败:" << m_udpSocket->errorString();
        emit discoveryFailed("UDP 端口绑定失败");
        return;
    }
    qDebug() << "✅ UDP 服务发现已启动，监听端口:" << m_udpPort;
}
```
⚠️ **此方法未被调用 → UDP 端口未绑定**

---

## 三、对比参考设备（192.168.10.98）

### 正常工作流程（推测）

1. **应用启动时自动调用 `startDiscovery()`**
2. **UDP 端口 8600 成功绑定**
3. **上位机发送 UDP 广播 → 设备接收 JSON**
4. **设备解析 JSON，获取服务器 IP:Port**
5. **TCP 连接 → WebSocket 握手 → 音频传输**

### 当前设备（192.168.10.188）的问题

1. ❌ `startDiscovery()` 未调用
2. ❌ UDP 端口 8600 未监听
3. ❌ ICMP Port Unreachable 错误
4. ❌ 协议流程中断

---

## 四、解决方案

### 方案 1: 自动启动 UDP 服务发现（推荐）⭐

#### 修改位置：CommonControl.cpp

```cpp
CommonControl::CommonControl(QObject *parent)
    : QObject(parent)
    , m_audioNetworkSender(new AudioNetworkSender(this))
    , m_audioNetworkTcpSender(new AudioNetworkTcpSender(this))
{
    // ✅ 2026-01-22 添加：自动启动 UDP 服务发现
    m_audioNetworkTcpSender->startDiscovery();
    qDebug() << "✅ CommonControl: TCP 音频模块已启动 UDP 服务发现";

    // 连接信号
    connect(m_audioNetworkTcpSender, &AudioNetworkTcpSender::discoverySucceeded,
            this, &CommonControl::onTcpDiscoverySucceeded);
    connect(m_audioNetworkTcpSender, &AudioNetworkTcpSender::tcpConnected,
            this, &CommonControl::onTcpConnected);
}
```

#### 优点
- ✅ 与参考设备（192.168.10.98）行为一致
- ✅ 应用启动后立即监听 UDP 端口
- ✅ 无需手动配置

#### 缺点
- ⚠️ 始终占用 UDP 端口 8600（即使不使用 TCP 模式）

---

### 方案 2: 按需启动 UDP 服务发现

#### 修改位置：CommonControl.cpp

```cpp
void CommonControl::configureTcpAudio()
{
    // 用户切换到 TCP 模式时才启动
    if (!m_audioNetworkTcpSender->isListening()) {
        m_audioNetworkTcpSender->startDiscovery();
        qDebug() << "✅ CommonControl: TCP 音频模式已激活";
    }
}
```

#### 优点
- ✅ 节省资源（仅在需要时启动）
- ✅ 灵活控制

#### 缺点
- ❌ 需要用户手动切换到 TCP 模式
- ❌ 与参考设备（192.168.10.98）行为不一致

---

## 五、验证步骤

### 1. 修改代码后重新编译
```powershell
.\build-ubuntu24-apt.ps1 188
```

### 2. 启动应用并查看日志
期望看到：
```
[DEBUG] ✅ AudioNetworkTcpSender 初始化完成
[DEBUG] ✅ CommonControl: TCP 音频模块已启动 UDP 服务发现
[DEBUG] ✅ UDP 服务发现已启动，监听端口: 8600
```

### 3. Wireshark 抓包验证

#### 预期结果：
```
Frame 1: UDP (上位机 192.168.10.142:8601 → 设备 192.168.10.188:8600)
    Payload: {"voiceport": 7800, "voicev4": [...]}

Frame 2: ❌ 不应该再有 ICMP Port Unreachable
```

#### 如果成功，应看到：
```
Frame 3: TCP SYN (设备 192.168.10.188 → 上位机 192.168.10.142:7800)
Frame 4: TCP SYN-ACK
Frame 5: TCP ACK
Frame 6: HTTP Upgrade (WebSocket 握手)
Frame 7: HTTP 101 Switching Protocols
```

### 4. 日志验证
```
[DEBUG] 📡 [UDP接收] 收到服务器配置：192.168.10.142:7800
[DEBUG] 🔌 [TCP连接] 正在连接到服务器...
[DEBUG] ✅ [TCP连接] 连接成功
[DEBUG] 🤝 [WebSocket] 握手完成
[DEBUG] 📤 [设备信息] 发送设备信息 JSON
```

---

## 六、关键代码修改位置

### 文件：src/control/CommonControl.cpp

#### 当前代码（第106行附近）
```cpp
CommonControl::CommonControl(QObject *parent)
    : QObject(parent)
    , m_audioNetworkSender(new AudioNetworkSender(this))
    , m_audioNetworkTcpSender(new AudioNetworkTcpSender(this))
{
    // ❌ 缺少 startDiscovery() 调用
}
```

#### 修改后代码
```cpp
CommonControl::CommonControl(QObject *parent)
    : QObject(parent)
    , m_audioNetworkSender(new AudioNetworkSender(this))
    , m_audioNetworkTcpSender(new AudioNetworkTcpSender(this))
{
    // ✅ 2026-01-22 添加：自动启动 UDP 服务发现
    m_audioNetworkTcpSender->startDiscovery();
    qDebug() << "✅ CommonControl: TCP 音频模块已启动 UDP 服务发现";
}
```

---

## 七、总结

| 项目 | 状态 |
|------|------|
| **编译成功** | ✅ 成功 |
| **AudioNetworkTcpSender 创建** | ✅ 成功 |
| **UDP 端口 8600 监听** | ❌ **未启动（根本原因）** |
| **上位机 UDP 广播** | ✅ 正常发送 |
| **设备响应** | ❌ ICMP Port Unreachable |
| **TCP 连接** | ❌ 未尝试（UDP 阶段失败） |
| **WebSocket 握手** | ❌ 未到达 |
| **音频传输** | ❌ 未到达 |

**下一步操作**：修改 CommonControl.cpp，添加 `startDiscovery()` 调用，重新编译验证。

---

**相关文档**：
- [TCP音频传输模式实施总结](docs/2026-01-22/01-TCP音频传输模式完整实施总结.md)
- [Wireshark抓包过滤指南](docs/2026-01-22/02-TCP音频协议Wireshark抓包过滤指南.md)
