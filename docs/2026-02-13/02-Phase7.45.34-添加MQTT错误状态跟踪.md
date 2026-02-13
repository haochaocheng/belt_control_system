# Phase 7.45.34 - 添加 MQTT 错误状态跟踪

**修复时间**: 2026-02-13 11:45
**问题类型**: 日志优化（Phase 7.45.33 的补充修复）
**严重程度**: 低（日志过多影响调试）

## 1. 问题回顾

### Phase 7.45.33 修复后的遗留问题

在 Phase 7.45.33 中，我们修复了 MQTTController 和 MQTTAutoManager 的重复日志问题，但部署后发现 **errorChanged 信号的日志仍然重复输出**：

```
[WARNING] ⚠️ [MQTTController] "模块1: 传输层无效"
[WARNING] ⚠️ [MQTTController] "模块2: 传输层无效"
[WARNING] ⚠️ [MQTTController] "模块3: 传输层无效"
[WARNING] ⚠️ [MQTTController] "模块4: 传输层无效"
...（重复数百次）
```

## 2. 根因分析

### 为什么 errorChanged 信号会重复输出？

1. **信号触发频率高**：
   - MQTT 客户端连接失败时，`errorChanged` 信号会频繁触发
   - 每次重连尝试都会触发 `TransportInvalid` 错误
   - 重连定时器每 5 秒触发一次，导致错误日志大量重复

2. **没有状态跟踪**：
   - Phase 7.45.33 只修复了 `connected/disconnected` 信号的重复日志
   - `errorChanged` 信号处理器没有状态跟踪机制
   - 每次错误发生都会输出日志，即使错误类型相同

3. **错误状态循环**：
   ```
   连接失败 → TransportInvalid 错误 → 输出日志
   5秒后重连 → 再次失败 → TransportInvalid 错误 → 输出日志
   循环往复...
   ```

## 3. 解决方案

### 核心思路

**添加错误状态跟踪，只在错误类型变化时输出日志。**

### 实现方式

1. 添加 `m_lastErrors` 向量，记录每个模块的上次错误状态
2. 在 `errorChanged` 信号处理器中比较当前错误与上次错误
3. 只在错误类型变化时输出日志

## 4. 修改内容

### 文件 1: `src/mqtt/MQTTController.h`

添加错误状态跟踪成员变量：

```cpp
#ifdef MQTT_ENABLED
    QVector<QMqttClient*> m_clients;
    QVector<QMap<QString, QMqttSubscription*>> m_subscriptions;

    // ✅ 2026-02-13 [Phase 7.45.34]: 添加错误状态跟踪
    // 用于避免重复输出相同的错误日志
    QVector<QMqttClient::ClientError> m_lastErrors;
#endif
```

### 文件 2: `src/mqtt/MQTTController.cpp`

#### 修改 1：初始化错误状态跟踪

```cpp
m_clients.resize(8);
m_subscriptions.resize(8);
// ✅ 2026-02-13 [Phase 7.45.34]: 初始化错误状态跟踪
m_lastErrors.resize(8, QMqttClient::NoError);
```

#### 修改 2：errorChanged 信号处理器添加状态检查

```cpp
connect(client, &QMqttClient::errorChanged, this, [this, moduleIndex](QMqttClient::ClientError error) {
    // ✅ 2026-02-13 [Phase 7.45.34]: 只在错误状态变化时输出日志
    if (error == m_lastErrors[moduleIndex]) {
        return;  // 错误状态未变化，不输出日志
    }
    m_lastErrors[moduleIndex] = error;

    QString errorStr;
    switch (error) {
    case QMqttClient::NoError:
        return;
    case QMqttClient::InvalidProtocolVersion:
        errorStr = "无效的协议版本";
        break;
    // ... 其他错误类型 ...
    case QMqttClient::TransportInvalid:
        errorStr = "传输层无效";
        break;
    // ...
    }

    m_lastError = QString("模块%1: %2").arg(moduleIndex + 1).arg(errorStr);
    qWarning() << "⚠️ [MQTTController]" << m_lastError;
    emit lastErrorChanged();
});
```

## 5. 技术要点

### 错误状态跟踪策略

| 组件 | 跟踪内容 | 数据类型 | 用途 |
|------|----------|----------|------|
| MQTTController | 错误类型 | `QMqttClient::ClientError` | 跟踪每个模块的错误状态 |
| MQTTAutoManager | 连接状态 | `bool` | 跟踪是否已连接（Phase 7.45.33） |

### 优化效果

- **修改前**：每次重连都输出 "传输层无效" 警告（每 5 秒 4 条）
- **修改后**：只在错误类型变化时输出（首次连接失败时输出一次）

### 预期日志输出

```
[DEBUG] ✅ [MQTTController] 创建客户端: 0
[WARNING] ⚠️ [MQTTController] "模块1: 传输层无效"  ← 首次输出
[DEBUG] 🔄 [MQTTAutoManager] 模块 0 断线，尝试重连
（5秒后重连，错误类型相同，不再输出）
（5秒后重连，错误类型相同，不再输出）
...
```

## 6. 验证步骤

1. 编译部署到设备
2. 运行程序，观察日志输出
3. 验证以下场景：
   - 首次连接失败时输出错误日志
   - 重连时如果错误类型相同，不再输出
   - 错误类型变化时（如从 TransportInvalid 变为 ServerUnavailable），输出新的错误日志
4. 确认日志文件大小不再快速增长

## 7. 与 Phase 7.45.33 的关系

### Phase 7.45.33（2026-02-12）
- 修复了 `connected/disconnected` 信号的重复日志
- 添加了 `m_lastConnectedStates` 状态跟踪
- 移除了 `connectToModule/disconnectFromModule` 中的日志

### Phase 7.45.34（2026-02-13）
- 修复了 `errorChanged` 信号的重复日志
- 添加了 `m_lastErrors` 错误状态跟踪
- 完善了 Phase 7.45.33 的日志优化工作

## 8. 经验教训

1. **信号处理器需要状态跟踪**：所有频繁触发的信号处理器都应该添加状态跟踪
2. **分阶段修复**：复杂问题可以分多个阶段修复，每次解决一个方面
3. **实际测试重要**：代码逻辑看起来正确，但实际运行可能有遗漏

## 9. 相关修复

- Phase 7.45.33 (2026-02-12): 优化 MQTT 调试日志输出（连接状态跟踪）
- Phase 7.45.33 修复 (2026-02-13): 彻底解决 MQTT 重复日志问题（移除底层日志）
- Phase 7.45.34 (2026-02-13): 添加 MQTT 错误状态跟踪（本次修复）
