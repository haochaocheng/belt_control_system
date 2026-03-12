# Phase 7.48.38 - 修复启动按钮TypeError与健康检查日志优化

## 修复日期
2026-03-12

## 问题描述

### 问题1：电机启动按钮不工作，语音不播放
- **现象**：点击基本配置中的启动按钮，电机不启动，预警语音不播放
- **日志错误**：`TypeError: Property 'machineNumber' of object SystemConfig is not a function`
- **位置**：`BasicConfigTab.qml:1055`

### 问题2：MQTTAutoManager 健康检查日志刷屏
- **现象**：每10秒打印4个模块的健康检查日志，状态正常时也持续输出
- **影响**：voip.md 日志被大量重复的健康检查信息淹没

## 原因分析

### 问题1
`systemConfig.machineNumber()` 使用了函数调用语法 `()`，但 `machineNumber` 是 Q_PROPERTY 属性，在 QML 中应作为属性访问（不加括号）。TypeError 导致整个 onClicked 处理函数中断，后续的 MQTT 发布和语音播放都未执行。

### 问题2
原实现使用计数器每10次输出一次日志，无论状态是否变化都会打印。4个模块 × 每10秒 = 大量重复日志。

## 修复方案

### 修复1：machineNumber 属性访问
**文件**：`src/qml/components/device_info/pages/BasicConfigTab.qml`

修改2处：
- 第56行（失败语音播放）
- 第1055行（预警语音播放）

```javascript
// 旧：systemConfig.machineNumber()  ← TypeError
// 新：systemConfig.machineNumber    ← 正确的属性访问
var beltNum = typeof systemConfig !== "undefined" ? systemConfig.machineNumber : 1
```

### 修复2：健康检查日志改为状态变化触发
**文件**：
- `src/mqtt/MQTTAutoManager.h` - 新增 `m_lastHealthStatus` 缓存
- `src/mqtt/MQTTAutoManager.cpp` - 重构 `checkModuleHealth()` 函数

主要改动：
1. 新增 `QVector<QString> m_lastHealthStatus` 缓存每个模块的上次状态
2. 将 `checkModuleHealth()` 中的 early return 改为 if-else 链，确保所有分支都能到达末尾的状态变化检测
3. 在函数末尾比较当前状态与缓存状态，仅在变化时打印日志

```cpp
// 状态变化检测：connected + status + timeoutCount 组合
QString currentStatus = QString("%1|%2|%3")
    .arg(health.connected).arg(health.status).arg(health.dataTimeoutCount);
if (m_lastHealthStatus[moduleIndex] != currentStatus) {
    qDebug() << "[MQTTAutoManager] 模块" << moduleIndex << "状态变化 | ...";
    m_lastHealthStatus[moduleIndex] = currentStatus;
}
```

## 修改文件清单
| 文件 | 修改内容 |
|------|---------|
| BasicConfigTab.qml | `machineNumber()` → `machineNumber`（2处） |
| MQTTAutoManager.h | 新增 `m_lastHealthStatus` 成员变量 |
| MQTTAutoManager.cpp | 重构 `checkModuleHealth()`，日志改为状态变化触发 |
