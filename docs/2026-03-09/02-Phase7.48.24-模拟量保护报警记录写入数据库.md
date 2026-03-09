# Phase 7.48.24 — 模拟量保护报警记录写入数据库

**日期**：2026-03-09
**阶段**：Phase 7.48.24
**类型**：功能增强

---

## 一、问题描述

模拟量（AI）保护触发报警时，只播放音频，**不记录到报警历史数据库**。

对比：
| 保护类型 | 音频播放 | 数据库记录 | 报警页面显示 |
|---------|---------|-----------|------------|
| DI（开关量） | ✅ | ✅ | ✅ |
| AI（模拟量） | ✅ | ❌ | ❌ |

---

## 二、修复方案

### 2.1 新增信号

在 `MqttProtectionMonitor` 中新增两个信号：

```cpp
// 模拟量保护触发（含工程量值和超限类型）
void analogProtectionTriggered(int beltNumber, const QString &protectionName,
                               double engineeringValue, const QString &limitType);

// 模拟量保护恢复（值回到正常范围）
void analogProtectionRestored(int beltNumber, const QString &protectionName,
                              double engineeringValue);
```

### 2.2 信号发射时机

利用 Phase 7.48.23 的边沿触发机制：
- **正常→超限**：`emit analogProtectionTriggered()`
- **超限→正常**：`emit analogProtectionRestored()`

### 2.3 main.cpp 连接

```cpp
// 触发记录
connect(monitor, &MqttProtectionMonitor::analogProtectionTriggered,
    [&db](int belt, QString name, double val, QString type) {
        db.saveAlarmTriggered(name + "(" + type + ")", belt号皮带, val);
    });

// 恢复记录
connect(monitor, &MqttProtectionMonitor::analogProtectionRestored,
    [&db](int belt, QString name, double val) {
        db.saveAlarmRestored(name);
    });
```

---

## 三、修改文件

| 文件 | 修改 |
|------|------|
| `src/control/MqttProtectionMonitor.h` | +2个信号声明 |
| `src/control/MqttProtectionMonitor.cpp` | 在边沿触发/恢复处 emit 信号 |
| `src/main/main.cpp` | 连接信号到 `alarmHistoryDB` |

---

## 四、报警记录格式

### 触发记录
| 字段 | 值 | 示例 |
|------|----|----- |
| protection_name | "保护名称(超限类型)" | "温度一(超上限)" |
| protection_type | "X号皮带" | "1号皮带" |
| event_type | "triggered" | — |
| trigger_value | 工程量值 | 65.3 |

### 恢复记录
| 字段 | 值 | 示例 |
|------|----|----- |
| protection_name | "保护名称" | "温度一" |
| event_type | "restored" | — |

---

## 五、数据流

```
MQTT数据 → onAIChannelChanged() → 边沿检测
    ├─ 正常→超限: emit analogProtectionTriggered()
    │   └─ main.cpp → alarmHistoryDB.saveAlarmTriggered()
    │       └─ emit alarmAdded() → AlarmPage自动刷新
    └─ 超限→正常: emit analogProtectionRestored()
        └─ main.cpp → alarmHistoryDB.saveAlarmRestored()
            └─ emit alarmAdded() → AlarmPage自动刷新
```

---

**文档版本**：v1.0
**创建时间**：2026-03-09
**状态**：已完成
