# Phase 7.48.88.72 - 反馈配置同步修复+运行中参数冻结

## 日期
2026-03-30

## 提交信息
- **Commit**: `79db893`
- **类型**: feat（新功能）

## 问题描述

### 问题1：反馈检测失效
`syncDeviceFeedbackConfigs()` 函数位于已废弃的 `ParameterSettings` 组件中，导致设备反馈配置无法同步到 `commonControl`。

### 问题2：运行中参数可修改
皮带运行时，用户仍可编辑设备配置参数，存在安全隐患。

## 修复方案

### 1. 反馈配置同步迁移
- 将 `syncDeviceFeedbackConfigs()` 从废弃的 `ParameterSettings` 迁移到 `ControlPanel.qml`
- 确保设备反馈配置在页面加载时正确同步

### 2. 运行中参数冻结
在所有4个设备配置面板中添加运行中冻结机制：

| 面板 | 冻结内容 |
|------|----------|
| BasicConfigTab | 电机配置所有参数+横幅提示 |
| BrakeConfigPanel | 制动器配置所有参数+横幅提示 |
| TensionControlConfigPanel | 张紧控制配置所有参数+横幅提示 |
| SprinklerConfigPanel | 洒水配置所有参数+横幅提示 |

### 3. 关键设计
- **停止按钮始终保持启用**（紧急停止不受冻结影响）
- 监听 `beltRunningChanged` 信号实时响应
- `Component.onCompleted` 初始化冻结状态

## 修改文件
| 文件 | 改动 |
|------|------|
| `ControlPanel.qml` | +76 行，迁移反馈同步逻辑 |
| `BasicConfigTab.qml` | +62/-2，电机配置冻结+横幅 |
| `BrakeConfigPanel.qml` | +78/-6，制动器冻结+横幅 |
| `TensionControlConfigPanel.qml` | +77/-4，张紧控制冻结+横幅 |
| `SprinklerConfigPanel.qml` | +48/-2，洒水冻结+横幅 |
| `MotorConfigPanel.qml` | +5，补充冻结支持 |
| `MotorControlPage.qml` | +22，传递运行状态 |
