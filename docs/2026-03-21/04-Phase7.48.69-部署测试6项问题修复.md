# Phase 7.48.69 - 部署测试6项问题修复

## 日期：2026-03-21

## 问题清单与修复

### 问题1：张紧控制前面没有显示启动延时
**根因**：设备卡片内没有显示延时文字。
**修复**：在 `LogicControlPanel.qml` 每个设备卡片的 Column 中新增 Text 元素，显示 "延时 X.Xs"，颜色根据延时长短变化（≤2s蓝色，≤5s橙色，>5s红色）。

### 问题2：进度条上的延时标签显示 (1.0s) 与实际不符
**根因**：QML `property var` 数组绑定 bug。`startupDelays = []` 后调用 `push()` 不触发 QML binding 重新评估，Text 在数组为空时绑定，读到 `undefined` 显示默认 1.0。
**修复**：`loadFromConfig()` 中先用临时数组 `tmpStartup` 累积，最后一次性赋值 `startupDelays = tmpStartup`，触发 binding 更新。同样处理 stopDelays。

### 问题3：电机反馈已关闭但启动时仍报运行失败
**根因**：`device_motor_config` 表没有 `use_feedback` 列。`loadMotorConfig()` 返回 undefined，`ParameterSettings.qml` 默认为 true。而 `saveMotorConfig()` 使用 INSERT OR REPLACE（先删后插），即使直接修改DB也会被覆盖丢失。
**修复**：
1. 迁移031：`ALTER TABLE device_motor_config ADD COLUMN use_feedback INTEGER DEFAULT 0`
2. `saveMotorConfig()` INSERT 语句新增 `use_feedback` 列（37列），bindValue 读取 config 中的 use_feedback

### 问题4a：故障后已激活设备仍显示绿色
**根因**：`rtPhase === 3` 只对 `rtFaultDevice` 显示红色，但 `isRealtimeActive && index < rtActivatedCount` 条件仍让前序设备保持绿色。
**修复**：`LogicControlPanel.qml` 设备卡片颜色逻辑中，`rtPhase === 3` 时提前返回默认颜色（非绿色），只有故障设备显示红色背景。

### 问题4b：运行失败音频播放默认路径而非TTS合成路径
**根因**：`getDeviceFailureAudioPath()` 缺少 TTS 路径检查，只查了数据目录和应用目录。而 `getAudioPath()` 在 Phase 7.48.60 已添加了 TTS 路径优先逻辑。
**修复**：在 `CommonControl.cpp::getDeviceFailureAudioPath()` 中添加 TTS 路径优先检查（与 `getAudioPath()` 对齐），当 `beltAudioSource() == 1` 时先在 TTS 文件夹查找。

### 问题6：文档记录
本文档即为问题6的修复。

## 修改文件清单

| 文件 | 改动 |
|------|------|
| `src/qml/components/device_info/pages/LogicControlPanel.qml` | 问题1+2: 修复QML binding + 卡片延时显示；问题4a: 故障后颜色重置 |
| `src/control/DeviceConfigManager.cpp` | 问题3: 迁移031新增use_feedback列 + saveMotorConfig扩展为37列 |
| `src/control/CommonControl.cpp` | 问题4b: getDeviceFailureAudioPath添加TTS路径优先检查 |
| `src/qml/pages/ParameterSettings.qml` | 已在Phase 7.48.68中修复（DB失败时默认关闭反馈） |
