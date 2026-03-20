# Phase 7.48.59 - 修复R键启动后无限循环重启

## 时间
2026-03-20

## 问题描述

Phase 7.48.58 修复后，按 R 键虽然能触发启动，但由于设备无法收到 Modbus 反馈（NetworkTask 未连接），导致以下无限循环：

```
🚀 开始执行启动顺序（第1次）
⏰ 张紧 反馈超时 → 故障停止
✅ 停止序列执行完成
⏰ CommonControl: 预警时间到达
🔄 CommonControl: 预警结束，自动启动设备序列  ← 自动重启！
🚀 开始执行启动顺序（第2次）
...
```

同时，每次启动后有3个设备（张紧、抱闸、1号电机）反馈超时，每个都各自触发一次完整的停止序列：

```
⏰ 张紧 反馈超时 → [1/4] 停止2号电机...
⏰ 抱闸 反馈超时 → [1/4] 停止2号电机...（并发）
⏰ 1号电机 反馈超时 → [1/4] 停止2号电机...（再次并发）
```

---

## 根本原因分析

### 根因1：warningTimer 是重复定时器（主因）

**文件**：`src/control/CommonControl.cpp`

`startWarningPlayback()` 调用 `m_warningTimer->start(N秒)` 时，**未设 singleShot**：

```cpp
// 旧代码（有问题）
m_warningTimer->start(warningTime * 1000);
// QTimer 默认 singleShot=false → 每 N 秒重复触发！
```

`onWarningTimerTimeout()` 每次触发都调用 `startDeviceSequence()`，造成设备序列无限重启。

### 根因2：fallback③ 未停止 warningTimer

**文件**：`src/control/CommonControl.cpp`，`playWarningOnce()` 函数

当 TTS 不可用时，`playWarningOnce()` 的兜底路径③直接调用 `startDeviceSequence()`，但**没有停止已启动的 warningTimer**：

```cpp
// 旧代码（有问题）
m_isWarningPlaying = false;   // ← 只改了标志，没有 stop()！
startDeviceSequence();
// m_warningTimer 仍在运行，N秒后再次触发 startDeviceSequence()
```

此时 `m_isWarningPlaying = false`，导致后续 `stopWarningPlayback()` 也无法停止它（因为检查了 `if (m_isWarningPlaying)`）。

### 根因3：多个反馈定时器并发触发停止序列

**文件**：`src/control/CommonControl.cpp`，`stopDeviceSequence()` 函数

启动序列激活4个设备，每个设备各有一个独立反馈超时定时器（3秒）。当第一个设备（张紧）超时触发 `stopDeviceSequence()` 时，其余设备（抱闸、1号电机、2号电机）的定时器仍在运行。`中断当前序列` 只停止了序列推进定时器，**没有取消这些反馈定时器**。

结果：后续定时器逐个超时，各自触发新的停止序列，日志中出现 `[1/4] 停止2号电机` 连续打印3次的现象。

---

## 修复方案

### 修复1：startWarningPlayback() 设 singleShot

```cpp
// ✅ 2026-03-20 [Phase 7.48.59]
m_warningTimer->setSingleShot(true);  // ← 新增
m_warningTimer->start(warningTime * 1000);
```

### 修复2：playWarningOnce() fallback③ 停止 warningTimer

```cpp
// ✅ 2026-03-20 [Phase 7.48.59]
m_warningTimer->stop();     // ← 新增：防止 N 秒后重复启动
m_isWarningPlaying = false;
startDeviceSequence();
```

### 修复3：stopDeviceSequence() 取消所有反馈检测

```cpp
// ✅ 2026-03-20 [Phase 7.48.59]：新增在序列停止之后、停止序列启动之前
if (!m_feedbackChecks.isEmpty()) {
    QList<QString> activeDevices = m_feedbackChecks.keys();
    qDebug() << "⏹️  CommonControl: 取消" << activeDevices.size() << "个反馈检测定时器:" << activeDevices.join(", ");
    for (const QString &device : activeDevices) {
        stopFeedbackCheck(device);
    }
}
```

---

## 修改文件清单

| 文件 | 修改内容 |
|------|---------|
| `src/control/CommonControl.cpp` | `startWarningPlayback()`：设 `m_warningTimer->setSingleShot(true)` |
| `src/control/CommonControl.cpp` | `playWarningOnce()` fallback③：先 `m_warningTimer->stop()` 再 `startDeviceSequence()` |
| `src/control/CommonControl.cpp` | `stopDeviceSequence()`：循环取消所有 `m_feedbackChecks` 中的定时器 |

---

## 修复后预期行为

### 场景1：TTS 不可用（当前测试环境）
- R键 → startWarningPlayback() → playWarningOnce() → TTS失败 → fallback③ → **stop warningTimer** → startDeviceSequence()
- 反馈超时 → stopDeviceSequence() → **取消所有反馈定时器**（只有1次停止序列）
- 停止完成后，**不再自动重启**（warningTimer 已停止）

### 场景2：TTS 可用
- R键 → startWarningPlayback() → TTS合成 → 播放语音 → **warningTimer（singleShot）超时** → startDeviceSequence()（仅触发一次）
- 正常流程后，如设备反馈超时，停止序列也只执行一次

---

## 遗留问题

- **NetworkTask 未连接**：测试环境中 Modbus 服务器不可达，所有设备控制指令无法发出，反馈恒为0。这是测试环境的正常现象，不是代码bug。
- **停车预警**：`stopBelt()` 的停车音频路径问题（`/app/AUDIO/` 不存在），已有直接调用 `stopDeviceSequence()` 的兜底逻辑，不影响停止功能。
