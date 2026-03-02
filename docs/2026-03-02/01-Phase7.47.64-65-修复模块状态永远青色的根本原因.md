# Phase 7.47.64-65 - 修复模块状态永远显示青色的根本原因

**日期**: 2026-03-02
**提交**: `7b36e7f4`
**修改文件**: `src/mqtt/MQTTAutoManager.cpp`, `src/mqtt/MQTTAutoManager.h`

---

## 一、问题描述

硬件模块正常发送数据时模块状态显示青色（在线），将模块电源拔掉后，模块状态**一直显示青色（在线）**，从未变化。重新通电后可以正常触发保护，但状态指示始终为"在线"。

---

## 二、根因分析（voip.md 日志揭露）

### 关键日志证据

```
模块 0 消息到达 | 主题: "station/status/1"   | 大小: 203 bytes | 更新健康状态: ❌否(VoIP/其他)
模块 0 消息到达 | 主题: "device/status/1"    | 大小: 171 bytes | 更新健康状态: ❌否(VoIP/其他)
模块 0 消息到达 | 主题: "station/status/1"   | 大小: 203 bytes | 更新健康状态: ❌否(VoIP/其他)
模块 0 消息到达 | 主题: "device/status/1"    | 大小: 171 bytes | 更新健康状态: ❌否(VoIP/其他)
```

日志每秒约2次，持续不断，且主题是 VoIP 相关，不是硬件模块主题。

### 订阅主题分析

模块0（开关量模块1）订阅了 **3 个** 主题：

| 主题 | 来源 | 数据频率 | 是否代表硬件在线 |
|------|------|---------|----------------|
| `belt_control/di/module1/status` | 硬件 DI 模块 | 硬件在线时 ~1次/秒 | ✅ 是 |
| `station/status/+` | VoIP 控制站心跳 | 持续不断（VoIP 在线时） | ❌ 否 |
| `device/status/+` | VoIP 设备心跳 | 持续不断（VoIP 在线时） | ❌ 否 |

### Bug 路径

```
VoIP 控制站心跳 → EMQX → 系统 MQTT 客户端(模块0) 收到 station/status/1
                         ↓
onModuleMessageReceived(0, "station/status/1", ...)
                         ↓
updateLastDataTime(0)    ← 硬件模块断电，但 VoIP 在跑
                         ↓
lastDataTime = now       ← 永远刷新！
status = "正常"          ← 永远"正常"
                         ↓
LED 永远青色             ← 无论硬件是否断电
```

**结论**：VoIP 的控制站/设备心跳消息通过与硬件模块共用同一个 MQTT 客户端（模块0的 client），持续刷新 `lastDataTime`，导致即使硬件模块断电，系统也认为模块在线。

---

## 三、修复方案（Phase 7.47.65）

**核心思路**：在 `onModuleMessageReceived()` 中增加主题过滤，只有来自硬件模块专属状态主题的消息才触发 `updateLastDataTime()`。

```cpp
// 硬件模块专属状态主题
QString expectedHardwareTopic;
if (moduleIndex < 2) {
    expectedHardwareTopic = QString("belt_control/di/module%1/status").arg(moduleIndex + 1);
} else if (moduleIndex < 4) {
    expectedHardwareTopic = QString("belt_control/ai/module%1/status").arg(moduleIndex - 1);
}

bool isHardwareTopic = (!expectedHardwareTopic.isEmpty() && topic == expectedHardwareTopic);
if (isHardwareTopic) {
    updateLastDataTime(moduleIndex);  // 只有硬件消息才更新在线状态
}

// 无论什么主题，都转发给数据管理器（VoIP 等功能不受影响）
emit moduleDataReceived(moduleIndex, topic, payload);
```

**效果**：
- `station/status/1`、`device/status/1` 等 VoIP 消息不再刷新 `lastDataTime`
- `belt_control/di/module1/status` 消息正常更新状态
- 硬件模块断电 → 5 秒内 LED 从青色变黄色

---

## 四、调试日志增强（Phase 7.47.64）

为了帮助诊断类似问题，新增以下日志：

| 位置 | 日志内容 | 频率 |
|------|---------|------|
| `checkModuleHealth()` | 每10秒输出 connected/lastDataTime/timeSinceLastData/status/timeoutCount | 低（10s/次） |
| `updateLastDataTime()` | 状态变化时输出（如"等待数据→正常"） | 低（变化时） |
| `onModuleMessageReceived()` | 主题名 + 是否更新健康状态 | 高（每条消息） |

---

## 五、修复后的三状态逻辑（最终正确版本）

```
模块状态判断逻辑：

connected = m_mqttController->isModuleConnected(moduleIndex)
          = 系统 MQTT 客户端是否连上 EMQX broker

lastDataTime = 最近一次收到 belt_control/{di|ai}/module{N}/status 的时间
             （VoIP 消息不计入）

status 状态机：
  connected=false → "未连接" → LED 红色
  connected=true, lastDataTime=0 → "等待数据" → LED 黄色
  connected=true, now-lastDataTime ≤ 5s → "正常" → LED 青色
  connected=true, now-lastDataTime > 5s → "等待数据" → LED 黄色（立即降级）
  connected=true, 持续超时3次 → "数据超时" → LED 黄色（发出告警）
```

### 三色 LED 含义

| 颜色 | moduleState | 含义 |
|------|-------------|------|
| 🔴 红色 | offline | 未连接 EMQX broker |
| 🟡 黄色 | connected | 连上 broker，但 5 秒内无硬件数据 |
| 🔵 青色 | online | 硬件模块正在发送数据（最近 5 秒内收到） |

---

## 六、问题排查过程

| Phase | 修复内容 | 是否解决根因 |
|-------|---------|------------|
| 7.47.62 | lastDataTime=0 时返回"等待数据" | 部分（解决初始连接问题） |
| 7.47.62.1 | 三色状态指示器 | 界面优化 |
| 7.47.62.2 | _healthTick 强制QML绑定刷新 | 部分（解决界面不刷新问题） |
| 7.47.63 | 数据超过阈值立即降级 | 部分（5秒响应，但 VoIP 导致永不触发） |
| **7.47.65** | **onModuleMessageReceived 主题过滤** | **✅ 根本原因** |
