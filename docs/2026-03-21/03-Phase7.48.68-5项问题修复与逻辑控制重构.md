# Phase 7.48.68 - 5项问题修复与逻辑控制重构

**日期**: 2026-03-21
**分支**: feature/hardware-video-codec

---

## 概述

部署测试发现5个问题，全部修复完成：制动器反馈误检、12设备独立逻辑控制、故障后时间轴状态错误、激活颜色不明显、延时参数缺失与不同步。

---

## 问题1：制动器反馈关闭但仍被检查

### 根因
`syncDeviceFeedbackConfigs()` 中，DB加载失败时fallback使用OutputDevicePanel硬编码`useFeedback:true`。电机反馈也硬编码为true。

### 修复
- 张紧/制动器/电机 DB加载失败时默认 `useFeedback = false`
- 电机从DB读取 `use_feedback` 字段，不再硬编码true

### 文件
- `src/qml/pages/ParameterSettings.qml` (+15/-5)

---

## 问题2：12设备独立逻辑控制

### 需求
Input1页面12个设备卡片，每个弹出独立的DeviceSettingsDialog，逻辑控制是该设备专属的。

### 实现
- 新建 `device_logic_configs` 表（迁移030），按 device_id 存储启停序列
- LogicControlPanel 从 `systemConfig` 改为 `deviceConfigMgr + deviceId`
- DeviceSettingsDialog 传入 `item.deviceId = root.deviceId`
- CommonControl 从 device_logic_configs 读取启停序列（带 JSON 解析）

### 文件
- `src/control/DeviceConfigManager.cpp` (+80) — 迁移030 + loadDeviceLogicConfig/saveDeviceLogicConfig
- `src/control/DeviceConfigManager.h` (+8)
- `src/control/CommonControl.cpp` (+40) — 从DB读取序列和延时
- `src/control/CommonControl.h` (+5)
- `src/main/main.cpp` (+1)
- `src/qml/components/device_info/pages/LogicControlPanel.qml` (重构)
- `src/qml/components/device_info/DeviceSettingsDialog.qml` (+3/-1)

---

## 问题3：设备故障后时间轴仍显示运行中

### 修复
- 新增 `Connections { target: runtimeTracker }` 监听 `onIsFaultChanged`
- 故障时：rtPhase=3, 停止刷新定时器, 显示"❌ 运行失败 - {设备名}"
- 故障设备卡片显示红色边框+红色背景

### 文件
- `src/qml/components/device_info/pages/LogicControlPanel.qml` (+20)

---

## 问题4：设备激活绿色填充不明显

### 修复
- 当前激活设备：`#004d22` → `#006633`
- 已激活前序设备：`#002211` → `#004422`
- 前缀节点激活色同步调亮

### 文件
- `src/qml/components/device_info/pages/LogicControlPanel.qml` (~8行颜色替换)

---

## 问题5：制动器启动延时 + 延时双向同步

### 5a. BrakeConfigPanel 新增
- "松闸启动延时" (release_startup_delay)
- "抱闸启动延时" (brake_startup_delay)
- DB迁移029: ALTER TABLE device_brake_config

### 5b. 延时双向同步
- 逻辑控制延时从设备配置表读取（readDeviceStartupDelay）
- 修改延时同步写回设备配置表（writeDeviceStartupDelay）
- DeviceConfigManager 新增 updateMotorStartupDelay/updateBrakeStartupDelay/updateTensionStartupDelay

### 文件
- `src/qml/components/device_info/pages/BrakeConfigPanel.qml` (+15)
- `src/control/DeviceConfigManager.cpp` (+50) — 迁移029 + update方法
- `src/control/DeviceConfigManager.h` (+5)

---

## 修改文件清单

| 文件 | 改动 |
|------|------|
| `src/qml/pages/ParameterSettings.qml` | 反馈默认值改false |
| `src/qml/components/device_info/pages/LogicControlPanel.qml` | 故障监听+颜色+per-device配置+延时同步 |
| `src/qml/components/device_info/pages/BrakeConfigPanel.qml` | 新增松闸/抱闸启动延时 |
| `src/qml/components/device_info/DeviceSettingsDialog.qml` | 传入deviceId |
| `src/control/DeviceConfigManager.cpp` | 迁移029-030 + 新增方法 |
| `src/control/DeviceConfigManager.h` | 新增方法声明 |
| `src/control/CommonControl.cpp` | 从DB读取逻辑配置 |
| `src/control/CommonControl.h` | 新增DeviceConfigManager引用 |
| `src/main/main.cpp` | 连接DeviceConfigManager |
