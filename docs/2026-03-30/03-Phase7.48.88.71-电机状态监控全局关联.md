# Phase 7.48.88.71 - 电机状态监控全局关联

## 问题描述

电机配置面板左侧列表的圆形LED和状态文本只反映配置状态（投入/禁用/未配置），不显示实际运行状态。当电机通过逻辑控制、2号键、R键启动时，LED应实时更新。

## 解决方案

### 信号来源

`CommonControl.deviceStatusChanged(int beltNumber, QString deviceName, bool isRunning)` 信号在 `activateDevice()` 中发出，设备名格式为 "X号电机"。该信号覆盖所有启动方式（逻辑控制、按键启动、手动控制）。

### 状态优先级

| 优先级 | 状态 | LED颜色 | 文本 | 动画 |
|--------|------|---------|------|------|
| 1 | 运行中 | `#00E676` (亮绿) | "运行中" | 闪烁 |
| 2 | 已停止(投入) | `#4CAF50` (绿色) | "已停止" | 无 |
| 3 | 禁用 | `#FF5722` (红色) | "禁用" | 无 |
| 4 | 未配置 | `#555555` (暗灰) | "未配置" | 无 |

### 闪烁动画

运行中的电机LED使用 `SequentialAnimation on opacity`，在 1.0 和 0.3 之间循环，周期1.2秒。

## 修改文件

### 1. MotorControlPage.qml
- 新增 `motorRunningStates` 属性（8元素布尔数组）
- 新增 `Connections` 监听 `commonControl.deviceStatusChanged`
- 解析 "X号电机" 格式，更新对应电机运行状态
- 在 `onLoaded` 中绑定传递 `motorRunningStates` 给 MyMotorListPanel

### 2. MyMotorListPanel.qml
- 新增 `motorRunningStates` 属性
- LED颜色逻辑：运行中（亮绿）> 已停止/投入（绿色）> 禁用（红色）> 未配置（暗灰）
- 文本逻辑：运行中 > 已停止 > 禁用 > 未配置
- 运行中LED添加闪烁动画
- 运行中文字颜色同步为亮绿

## 日期
2026-03-30
