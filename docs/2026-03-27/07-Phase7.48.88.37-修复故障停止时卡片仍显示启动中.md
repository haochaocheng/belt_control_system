# Phase 7.48.88.37 - 修复故障停止时卡片仍显示"启动中"

## 修改时间
2026-03-27

## 问题描述

设备启动完成并运行后，张紧控制反馈超时触发故障停止。在执行停止序列期间，卡片左上角状态仍然显示"启动中"，而不是"停止中"。

## 根因分析

`Screen01.qml` 的 `onBeltSequenceProgress` 判断是启动还是停止序列时，检查条件为：

```javascript
var isStopSequence = (item.deviceStatus === "停车预警" || item.deviceStatus === "停止中")
```

**故障停止会跳过停车预警**，此时 `deviceStatus` 仍然是 `"运行"`（启动序列完成后设置的状态），导致 `isStopSequence = false`，停止序列的进度更新显示为"启动中"。

### 时序

1. 启动序列完成 → `deviceStatus = "运行"`
2. 反馈超时 → 触发故障停止（跳过停车预警）
3. 停止序列进度到达 → `isStopSequence = ("运行" === "停车预警")` → **false** → 显示"启动中"

## 修复方案

在停止序列判断中增加 `"运行"` 状态。当皮带处于"运行"状态时收到序列进度更新，说明正在执行停止序列（故障停车场景）。

```javascript
var isStopSequence = (item.deviceStatus === "停车预警" || item.deviceStatus === "停止中" || item.deviceStatus === "运行")
```

## 修改文件

| 文件 | 修改内容 |
|------|---------|
| `src/qml/Input1/Input1Content/Screen01.qml` | onBeltSequenceProgress 停止序列判断增加"运行"状态 |
