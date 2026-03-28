# Phase 7.48.88.46 - 修复故障停止时卡片仍显示"启动中"

## 日期
2026-03-28

## 问题描述

设备启动过程中如果反馈检测超时触发故障停止，设备监控卡片上的状态仍显示"启动中"，应该显示"停止中"。

## 根因分析

故障停止流程跳过停车预警（`m_isFaultStop = true`），直接执行停止序列。但此时QML卡片的 `deviceStatus` 仍为"启动中"。

Screen01.qml 中判断是否为停止序列的逻辑：
```javascript
var isStopSequence = (item.deviceStatus === "停车预警" || item.deviceStatus === "停止中" || item.deviceStatus === "运行")
```

"启动中"不在判断条件内，导致 `isStopSequence = false`，停止序列进度被误显示为"启动中"。

### 问题链路

1. ���动序列执行中 → 卡片状态为"启动中"
2. 反馈检测超时 → 触发故障停止
3. `stopDeviceSequence()` 跳过停车预警（`m_isFaultStop = true`）
4. 直接执行停止设备序列 → 发出 `beltSequenceProgress` 信号
5. Screen01 收到信号 → `deviceStatus === "启动中"` ��� `isStopSequence = false`
6. 卡片继续显示"启动中"（应为"停止中"）

## 修复方案

### 1. C++ 端（CommonControl.cpp）

故障停止时，在执行停止序列前发出"故障停止"阶段信号：

```cpp
if (m_isFaultStop) {
    // 通知QML切换到"停止中"状态
    emit beltSequenceProgress(actualBelt, "故障停止", 0, 0, 0);
    m_isFaultStop = false;
}
```

### 2. QML 端（Screen01.qml）

处理"故障停止"信号，将卡片状态设为"停止中"：

```javascript
} else if (phase === "故障停止") {
    item.deviceStatus = "停止中"
}
```

## 影响范围

- 修复故障停止时卡片状态显示不正确的问题
- 不影响正常启停流程
- 不影响 LogicControlPanel 时间轴（通过 RuntimeTracker 独立同步）

## 验证要点

1. 启动过程中反馈超时 → 卡片应显示"停止中"（非"启动中"）
2. 正常启动 → 卡片正确显示"启动中"
3. 正常停止 → 卡片正确显示"���止中"
