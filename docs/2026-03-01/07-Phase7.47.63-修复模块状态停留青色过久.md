# Phase 7.47.63 - 修复模块状态停留青色过久

**日期**: 2026-03-01
**提交**: `f9b0b2ef`
**修改文件**: `src/mqtt/MQTTAutoManager.cpp`

---

## 一、问题描述

MQTTX 发送消息后断开连接，或用户关闭 MQTT 后，模块状态 LED 仍然显示**青色（在线）**，需要等待 6~8 秒甚至更久才变黄色。

---

## 二、根因分析

### Bug 1：checkModuleHealth() 超时期间不更新状态

```
数据停止后的状态变化（旧逻辑）：

t=T+1s: timeSinceLastData=1 ≤ 5  → else分支 → dataTimeoutCount=0 → 不改 status → 青色
t=T+2s: timeSinceLastData=2 ≤ 5  → else分支 → dataTimeoutCount=0 → 不改 status → 青色
t=T+5s: timeSinceLastData=5 ≤ 5  → else分支 → dataTimeoutCount=0 → 不改 status → 青色
t=T+6s: timeSinceLastData=6 > 5  → dataTimeoutCount=1 → status 不变("正常") → 青色 ❌
t=T+7s: timeSinceLastData=7 > 5  → dataTimeoutCount=2 → status 不变("正常") → 青色 ❌
t=T+8s: timeSinceLastData=8 > 5  → dataTimeoutCount=3 ≥ 3 → status="数据超时" → 黄色 ✅
```

**问题**：`timeSinceLastData > threshold` 时，在 `dataTimeoutCount < MAX_TIMEOUT_COUNT` 期间 status 不被更新，仍停留在"正常"，LED 仍为青色。

### Bug 2：onModuleConnected(false) 未重置 lastDataTime

当系统 MQTT 客户端断开 broker 后自动重连（`onReconnectTimerTimeout` 每5秒触发），若 EMQX 上有 retained 消息，重连后订阅主题时 EMQX 立即推送 retained 消息：

```
系统断线 → 重连 → 订阅主题 → EMQX 推送 retained 消息 → updateLastDataTime()
→ lastDataTime = now → status="正常" → 永远青色
```

---

## 三、修复方案

### Fix 1：超过阈值立即降级（`checkModuleHealth`）

```cpp
if (timeSinceLastData > DATA_TIMEOUT_THRESHOLD) {
    // ✅ 2026-03-01 [Phase 7.47.63]: 超过阈值立即降级 "正常" → "等待数据"
    if (health.status == "正常") {
        health.status = "等待数据";
        qDebug() << "⚠️ [MQTTAutoManager] 模块" << moduleIndex << "数据中断，等待恢复";
    }
    health.dataTimeoutCount++;
    if (health.dataTimeoutCount >= MAX_TIMEOUT_COUNT) {
        health.status = "数据超时";
        ...
    }
}
```

效果：数据停止 5 秒后，LED **立即**从青色变黄色。

### Fix 2：断开时重置数据状态（`onModuleConnected(false)`）

```cpp
} else {
    m_healthStatus[moduleIndex].status = "未连接";
    // ✅ 2026-03-01 [Phase 7.47.63]: 断开时重置数据状态
    m_healthStatus[moduleIndex].lastDataTime = 0;
    m_healthStatus[moduleIndex].dataTimeoutCount = 0;
    ...
}
```

效果：重连后进入"等待数据"，只有新鲜数据才能进入"正常"。

---

## 四、状态流转图（修复后）

```
[正常/青色] --数据停止>5s--> [等待数据/黄色] --再>3s--> [数据超时/黄色]
[等待数据/黄色] --新数据到达--> [正常/青色]
[断开] --重连--> [等待数据/黄色] --新数据到达--> [正常/青色]
```

**用户测试体验**：
| 操作 | 旧行为 | 新行为 |
|------|--------|--------|
| MQTTX 断开后立即看 | 青色（最多等8秒） | 青色（最多等5秒） |
| MQTTX 断开5秒后 | 青色 ❌ | 黄色 ✅ |
| 系统断开重连后 | 青色（retained消息刷新） | 黄色（lastDataTime重置） |

---

## 五、架构说明

- **`connected=true`（黄色/等待）**：系统已连到 EMQX broker，但无硬件/测试工具数据
- **`status="正常"`（青色/在线）**：最近5秒内收到数据，硬件实际在线
- MQTTX 作为"硬件模拟器"：只要停止发送消息，5秒内就会降级为黄色
