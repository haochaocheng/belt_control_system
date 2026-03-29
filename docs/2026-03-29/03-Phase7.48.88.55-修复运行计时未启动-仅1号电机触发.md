# Phase 7.48.88.55 - 修复运行计时未启动（仅1号电机触发）

## 修改日期
2026-03-29

## 问题描述
部署 Phase 7.48.88.54 后，��片上的今日运行时间依然显示 00:00:00 不更新，开机率始终为 0%。

## 原因分析
`DeviceRuntimeTracker::startRunning()` 仅在 `onMotor1Starting()` 中调用，而当前皮带（2号）的启动序列为：

```
张紧控制 → 1号制动器 → 2号电机
```

**没有1号电��**，只有2号电机。因此：
1. `onMotor1Starting()` 从未被调用
2. `startRunning()` 从未执行
3. `m_isRunning` 始终为 false
4. `updateRuntime()` 每秒触发但立即 return（第一行检查 `!m_isRunning`）
5. `dailyRuntimeChanged` 信号从未发射
6. QML 端无论用 Connections 还是 Timer 都读到 "00:00:00"

### 日志佐证
```
[DEBUG] 🚀 CommonControl: 2号皮带开始执行启动顺序: "张紧控制 → 1号制动器 → 2号电机"
[DEBUG] 🔓 DeviceRuntimeTracker: 正在松闸     ← onBrakeReleasing()
[DEBUG] ⚡ DeviceRuntimeTracker: 2号电机启动  ← onMotor2Starting()，但未调用 startRunning()
[DEBUG] ✅ DeviceRuntimeTracker: 正在运行      ← onRunning()，也未调用 startRunning()
```

缺少：`▶️ DeviceRuntimeTracker: 开始运行计时` ← 从未出现

## 修复方案

### `src/control/DeviceRuntimeTracker.cpp`

| 函数 | 修改前 | 修改后 |
|------|--------|--------|
| `onMotor2Starting()` | 只更新状态 | 增加 `startRunning()` |
| `onRunning()` | 只更新状态 | 增加 `startRunning()`（最终兜底） |
| `onDeviceStatusChanged()` | 只匹配电机1 | 增加电机2匹配 |

`startRunning()` 内部有 `if (m_isRunning) return;` 保护，重复调用无副作用。

### 三层保障
1. **onMotor1Starting()** — 1号电机启动时计时（原有）
2. **onMotor2Starting()** — 2号电机启动时计时（新增）
3. **onRunning()** — 设备进入运行状态时计时（新增，兜底）

## 测试要点
1. 启动皮带后，日志应出现 `▶️ DeviceRuntimeTracker: 开始运行计时`
2. 运行时间每秒递增
3. 开机率随运行时间增加
4. 停止后运行时间停止但保留累计值
