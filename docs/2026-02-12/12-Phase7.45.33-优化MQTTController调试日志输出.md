# Phase 7.45.33 - 优化 MQTT 调试日志输出

**修复时间**: 2026-02-12 18:45（更新：19:00）
**问题类型**: 日志优化
**严重程度**: 低（日志过多影响调试）

## 1. 问题现象

### voip.md 日志分析
MQTT 相关的调试信息大量重复输出，共 **2042 条**日志：

**MQTTController 重复日志**：
```
[DEBUG] ✅ [MQTTController] 连接模块: 0
[DEBUG] ✅ [MQTTController] 连接模块: 1
[DEBUG] ✅ [MQTTController] 断开模块: 0
[DEBUG] ✅ [MQTTController] 断开模块: 1
...（重复数百次）
```

**MQTTAutoManager 重复日志**：
```
[DEBUG] 🔌 [MQTTAutoManager] 连接模块: 0  (64次)
[DEBUG] 🔄 [MQTTAutoManager] 重连模块: 0  (63次)
[DEBUG] 🔄 [MQTTAutoManager] 模块 0 断线，尝试重连  (63次)
[DEBUG] ⚠️ [MQTTAutoManager] 模块 0 已断开  (63次)
...
```

### 影响
- 日志文件快速增长
- 难以查找其他重要信息
- 调试效率降低

## 2. 根因分析

### 问题原因
1. **MQTTController**: `connectToModule()` 和 `disconnectFromModule()` 被频繁调用，每次都输出日志
2. **MQTTAutoManager**: 重连定时器每 5 秒检查一次，每次都输出日志

### 调用场景
- MQTT 重连定时器（5秒间隔）
- 配置更新时重新连接
- 界面切换时的连接检查

## 3. 解决方案

添加状态跟踪机制，**只在连接状态变化时输出调试信息**。

### 实现方式
1. **MQTTController**: 添加 `m_lastStates` 向量，记录每个模块的 `QMqttClient::ClientState`
2. **MQTTAutoManager**: 添加 `m_lastConnectedStates` 向量，记录每个模块的连接状态
3. 在相关方法中比较当前状态与上次状态，只在变化时输出

## 4. 修改文件

### 文件 1: `src/mqtt/MQTTController.h`

添加状态跟踪成员变量：

```cpp
#ifdef MQTT_ENABLED
    QVector<QMqttClient*> m_clients;
    QVector<QMap<QString, QMqttSubscription*>> m_subscriptions;

    // ✅ 2026-02-12 [Phase 7.45.33]: 添加连接状态跟踪
    QVector<QMqttClient::ClientState> m_lastStates;
#endif
```

### 文件 2: `src/mqtt/MQTTController.cpp`

#### 修改 1：初始化状态跟踪
```cpp
m_clients.resize(8);
m_subscriptions.resize(8);
m_lastStates.resize(8, QMqttClient::Disconnected);
```

#### 修改 2：connectToModule() - 只在状态变化时输出
```cpp
QMqttClient *client = m_clients[idx];
QMqttClient::ClientState currentState = client ? client->state() : QMqttClient::Disconnected;

// 只在状态变化时输出
if (currentState != m_lastStates[idx] || !client) {
    qDebug() << "✅ [MQTTController] 连接模块:" << idx
             << "状态:" << (client ? QString::number(static_cast<int>(currentState)) : "无客户端");
    m_lastStates[idx] = currentState;
}
```

#### 修改 3：disconnectFromModule() - 只在状态变化时输出
```cpp
QMqttClient *client = m_clients[idx];
if (client) {
    QMqttClient::ClientState currentState = client->state();

    if (currentState != m_lastStates[idx]) {
        qDebug() << "✅ [MQTTController] 断开模块:" << idx
                 << "状态:" << static_cast<int>(currentState);
        m_lastStates[idx] = currentState;
    }

    client->disconnectFromHost();
}
```

### 文件 3: `src/mqtt/MQTTAutoManager.h`

添加状态跟踪成员变量：

```cpp
// 健康状态
QVector<ModuleHealthStatus> m_healthStatus;

// ✅ 2026-02-12 [Phase 7.45.33]: 添加连接状态跟踪
QVector<bool> m_lastConnectedStates;
```

### 文件 4: `src/mqtt/MQTTAutoManager.cpp`

#### 修改 1：初始化状态跟踪
```cpp
void MQTTAutoManager::initializeHealthStatus()
{
    m_healthStatus.resize(8);
    m_lastConnectedStates.resize(8, false);
    // ...
}
```

#### 修改 2：onReconnectTimerTimeout() - 只在状态变化时输出
```cpp
for (int i = 0; i < 4; ++i) {
    bool isConnected = m_mqttController->isModuleConnected(i);

    // 只在状态变化时输出
    if (isConnected != m_lastConnectedStates[i]) {
        if (!isConnected) {
            qDebug() << "🔄 [MQTTAutoManager] 模块" << i << "断线，尝试重连";
        }
        m_lastConnectedStates[i] = isConnected;
    }

    if (!isConnected) {
        reconnectModule(i);
    }
}
```

#### 修改 3：reconnectModule() - 移除重复日志
```cpp
// ✅ 2026-02-12 [Phase 7.45.33]: 移除重复日志，状态变化已在 onReconnectTimerTimeout 中输出
// qDebug() << "🔄 [MQTTAutoManager] 重连模块:" << moduleIndex;
```

#### 修改 4：connectModule() - 移除重复日志
```cpp
// ✅ 2026-02-12 [Phase 7.45.33]: 移除重复日志，连接状态变化会在 MQTTController 中输出
// qDebug() << "🔌 [MQTTAutoManager] 连接模块:" << moduleIndex;
```

#### 修改 5：onModuleConnected() - 只在状态变化时输出
```cpp
if (connected) {
    // 只在状态变化时输出
    if (!m_lastConnectedStates[moduleIndex]) {
        qDebug() << "✅ [MQTTAutoManager] 模块" << moduleIndex << "已连接";
        m_lastConnectedStates[moduleIndex] = true;
    }
} else {
    // 只在状态变化时输出
    if (m_lastConnectedStates[moduleIndex]) {
        qDebug() << "⚠️ [MQTTAutoManager] 模块" << moduleIndex << "已断开";
        m_lastConnectedStates[moduleIndex] = false;
    }
}
```

## 5. 技术要点

### 状态跟踪策略

| 类 | 跟踪内容 | 数据类型 | 用途 |
|----|----------|----------|------|
| MQTTController | 客户端状态 | `QMqttClient::ClientState` | 跟踪连接/断开/连接中状态 |
| MQTTAutoManager | 连接状态 | `bool` | 跟踪是否已连接 |

### 优化效果

- **修改前**：2042 条 MQTT 日志（大量重复）
- **修改后**：预计减少 95% 以上（只在状态变化时输出）

## 6. 验证步骤

1. 编译部署到设备
2. 运行程序，观察日志输出
3. 验证以下场景：
   - 首次连接时输出日志
   - 连接成功后不再重复输出
   - 断开连接时输出日志
   - 重新连接时输出状态变化
4. 确认日志文件大小不再快速增长

## 7. 预期效果

### 修改前日志（重复输出）
```
[DEBUG] 🔌 [MQTTAutoManager] 连接模块: 0
[DEBUG] 🔌 [MQTTAutoManager] 连接模块: 0
[DEBUG] 🔌 [MQTTAutoManager] 连接模块: 0
...（重复 64 次）
```

### 修改后日志（只在变化时输出）
```
[DEBUG] ✅ [MQTTController] 连接模块: 0 状态: 0
[DEBUG] ✅ [MQTTController] 连接模块: 0 状态: 1
[DEBUG] ✅ [MQTTAutoManager] 模块 0 已连接
[DEBUG] ✅ [MQTTAutoManager] 模块 0 订阅主题: belt_control/di/module1/status
```

## 8. 相关修复

- Phase 7.45.32: 修复图片资源缺失问题
- Phase 7.45.31: 修复 QPainter 警告
- Phase 7.45.30: 修复 Input1Page 尺寸无限循环
