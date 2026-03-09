# Phase 7.48.23 — 修复模拟量保护报警无限循环

**日期**：2026-03-09
**阶段**：Phase 7.48.23
**类型**：BUG修复

---

## 一、问题描述

### 1.1 现象

部署后开机立即连续播放报警，"1号皮带"反复播放不停止。日志显示多个保护互相替代：

```
温度一报警触发 → 播放1次 → 电压报警触发 → 替代温度一(已播1/3次)
→ 电压播放1次 → 温度一又触发 → 替代电压(已播1/3次)
→ 无限循环...
```

### 1.2 根本原因

当前是**"电平触发"模式**：每次MQTT数据更新（~100ms间隔）都重新检测超限，只要值仍然超限就**反复调用`playAlarm()`**。

结合 Phase 7.48.2 的"last wins"替代策略（新报警替代旧报警），当多个保护同时超限时：
1. 保护A超限 → `playAlarm("A")` → 开始播放
2. 100ms后保护B超限 → `playAlarm("B")` → 替代A（A只播了1次）
3. 100ms后A数据又来 → `playAlarm("A")` → 替代B（B只播了1次）
4. 无限循环，每次播放都被中断，用户只听到片段

### 1.3 缺失的机制

| 机制 | 状态 | 说明 |
|------|------|------|
| 报警状态追踪 | ❌ 无 | 不知道同一保护是否已触发过 |
| 边沿检测 | ❌ 无 | 每次检测都当新触发处理 |
| 播放计数保护 | ❌ 被重置 | 新触发会将 currentPlayCount 重置为0 |

---

## 二、修复方案 — 边沿触发

### 2.1 设计原理

改为**"边沿触发"模式**（工业PLC/SCADA标准做法）：

```
正常 → 超限：触发报警（仅此一次）
超限 → 超限：忽略（持续超限不重复触发）
超限 → 正常：清除状态（记录恢复日志）
正常 → 超限：重新触发报警
```

### 2.2 数据结构

```cpp
// MqttProtectionMonitor.h
// Key = "皮带编号:保护名称" (如 "1:温度一")
// Value = true=当前超限已触发, false=正常
QMap<QString, bool> m_protectionAlarmActive;
```

### 2.3 逻辑流程

```
每次 onAIChannelChanged():
  计算工程量，判断是否超限
  ↓
  if (未超限) {
    if (之前是超限状态) → 标记恢复，打印恢复日志
    continue
  }
  ↓
  if (已在超限状态) → continue（不重复触发）
  ↓
  标记为超限状态 → playAlarm()（首次触发）
```

---

## 三、代码修改

### 3.1 修改文件

| 文件 | 修改位置 | 说明 |
|------|---------|------|
| `src/control/MqttProtectionMonitor.h` | 第196行后 | 新增 `m_protectionAlarmActive` 成员变量 |
| `src/control/MqttProtectionMonitor.cpp` | `onAIChannelChanged()` 第418-420行 | 替换为边沿触发逻辑 |
| `src/control/MqttProtectionMonitor.cpp` | `stop()` 方法 | 清理报警状态 |

### 3.2 修改前后对比

**修改前**（电平触发）：
```cpp
if (!exceeded) {
    continue;  // 未超限
}
// 直接触发报警（每次数据更新都触发）
playAlarm(...)
```

**修改后**（边沿触发）：
```cpp
QString alarmKey = QString("%1:%2").arg(beltNumber).arg(protName);

if (!exceeded) {
    if (m_protectionAlarmActive.value(alarmKey, false)) {
        m_protectionAlarmActive[alarmKey] = false;  // 恢复
    }
    continue;
}

if (m_protectionAlarmActive.value(alarmKey, false)) {
    continue;  // 持续超限，已触发过，跳过
}

m_protectionAlarmActive[alarmKey] = true;  // 首次超限
playAlarm(...)  // 只触发一次
```

---

## 四、效果

### 修复前

```
[WARNING] ⚠️ 模拟量保护触发（超上限）: "温度一" 工程量: 65.3 >= 42
[DEBUG] 🔄 新触发替代旧触发，停止当前播放并清空队列
[WARNING] ⚠️ 模拟量保护触发（超上限）: "电压" 工程量: 814.8 >= 700
[DEBUG] 🔄 新触发替代旧触发，停止当前播放并清空队列
[WARNING] ⚠️ 模拟量保护触发（超上限）: "温度一" 工程量: 65.5 >= 42
[DEBUG] 🔄 新触发替代旧触发...（无限循环）
```

### 修复后

```
[DEBUG] 🔔 模拟量保护首次触发: "温度一" 皮带 1
[DEBUG] 🔊 模拟量保护触发播放: ...温度一.wav 模式: count 次数: 3
[DEBUG] 🔔 模拟量保护首次触发: "电压" 皮带 1
（温度一被电压替代，电压播放完整3次）
（后续数据更新：温度一和电压都持续超限，但不再重复触发）
[DEBUG] ✅ 模拟量保护恢复: "温度一" 皮带 1 工程量: 38.2
（值恢复正常后，再次超限才会重新触发）
```

---

**文档版本**：v1.0
**创建时间**：2026-03-09
**状态**：已完成
